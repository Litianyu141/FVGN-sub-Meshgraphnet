# Lint as: python3
# pylint: disable=g-bad-file-header
# Copyright 2020 DeepMind Technologies Limited. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or  implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# ============================================================================
"""Model for CylinderFlow."""

import sonnet as snt
import tensorflow as tf

from meshgraphnets import common
from meshgraphnets import core_model
from meshgraphnets import normalization


class Model(snt.AbstractModule):
  """Model for fluid simulation."""

  def __init__(self, learned_model, dual_edge, name='Model'):
    super(Model, self).__init__(name=name)
    self._dual_edge=dual_edge
    with self._enter_variable_scope():
      self._learned_model = learned_model
      '''now have pressure'''
      self._output_normalizer = normalization.Normalizer(
          size=3, name='output_normalizer')
      self._node_normalizer = normalization.Normalizer(
          size=2+common.NodeType.SIZE, name='node_normalizer')
      self._edge_normalizer = normalization.Normalizer(
          size=3, name='edge_normalizer')  # 2D coord + length

  def _build_graph(self, inputs, is_training):
    """Builds input graph."""
    # construct graph nodes
    node_type = tf.one_hot(inputs['node_type'][:, 0], common.NodeType.SIZE)
    node_features = tf.concat([inputs['velocity'], node_type], axis=-1)

    # construct graph edges
    senders, receivers = common.triangles_to_edges(inputs['cells'],dual_edge=self._dual_edge)
    relative_mesh_pos = (tf.gather(inputs['mesh_pos'], senders) -
                         tf.gather(inputs['mesh_pos'], receivers))
    edge_features = tf.concat([
        relative_mesh_pos,
        tf.norm(relative_mesh_pos, axis=-1, keepdims=True)], axis=-1)

    mesh_edges = core_model.EdgeSet(
        name='mesh_edges',
        features=self._edge_normalizer(edge_features, is_training),
        receivers=receivers,
        senders=senders)
    return core_model.MultiGraph(
        node_features=self._node_normalizer(node_features, is_training),
        edge_sets=[mesh_edges])

  def _build(self, inputs):
    graph = self._build_graph(inputs, is_training=False)
    per_node_network_output = self._learned_model(graph)
    return self._update(inputs, per_node_network_output)

  @snt.reuse_variables
  def loss(self, inputs):
    """L2 loss on velocity."""
    graph = self._build_graph(inputs, is_training=True)
    network_output = self._learned_model(graph)

    # build target velocity change
    cur_velocity = inputs['velocity']
    target_velocity = inputs['target|velocity']
    target_pressure = inputs['target|pressure']
    target_velocity_change = target_velocity - cur_velocity
    target_normalized = self._output_normalizer(tf.concat([target_velocity_change,target_pressure],axis=1))

    # build loss
    node_type = inputs['node_type'][:, 0]
    loss_mask = tf.logical_or(tf.equal(node_type, common.NodeType.NORMAL),
                              tf.equal(node_type, common.NodeType.OUTFLOW))
    error = (target_normalized - network_output)**2
    loss_uv = tf.reduce_mean(tf.reduce_sum(error[:,0:2],axis=1)[loss_mask])
    loss_p = tf.reduce_mean(error[:,2])
    loss = loss_uv+loss_p

    tf.summary.scalar('loss_uv', loss_uv)
    tf.summary.scalar('loss_p', loss_p)
  
    return loss

  def _update(self, inputs, per_node_network_output):
    """Integrate model outputs."""
    velocitya_and_pressure_update = self._output_normalizer.inverse(per_node_network_output)
    # integrate forward
    cur_velocity = inputs['velocity']
    predicted_pressure = velocitya_and_pressure_update[:,2:3]
    return cur_velocity + velocitya_and_pressure_update[:,0:2],predicted_pressure
