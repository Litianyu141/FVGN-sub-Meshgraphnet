#include <stdio.h>
#include <stdlib.h>
#include <time.h>

//CUDA RunTime API
#include <cuda_runtime.h>

#define DATA_SIZE 1048576

int data[DATA_SIZE];
void printDeviceProp(const cudaDeviceProp& prop)
{
	printf("Device Name : %s.\n", prop.name);
	printf("totalGlobalMem : %d.\n", prop.totalGlobalMem);
	printf("sharedMemPerBlock : %d.\n", prop.sharedMemPerBlock);
	printf("regsPerBlock : %d.\n", prop.regsPerBlock);
	printf("warpSize : %d.\n", prop.warpSize);
	printf("memPitch : %d.\n", prop.memPitch);
	printf("maxThreadsPerBlock : %d.\n", prop.maxThreadsPerBlock);
	printf("maxThreadsDim[0 - 2] : %d %d %d.\n", prop.maxThreadsDim[0], prop.maxThreadsDim[1], prop.maxThreadsDim[2]);
	printf("maxGridSize[0 - 2] : %d %d %d.\n", prop.maxGridSize[0], prop.maxGridSize[1], prop.maxGridSize[2]);
	printf("totalConstMem : %d.\n", prop.totalConstMem);
	printf("major.minor : %d.%d.\n", prop.major, prop.minor);
	printf("clockRate : %d.\n", prop.clockRate);
	printf("textureAlignment : %d.\n", prop.textureAlignment);
	printf("deviceOverlap : %d.\n", prop.deviceOverlap);
	printf("multiProcessorCount : %d.\n", prop.multiProcessorCount);
}

void GenerateNumbers(int* number, int size)    //��������0-9֮��������
{
	for (int i = 0; i < size; i++) {
		number[i] = rand() % 10;
	}
}

//CUDA ��ʼ��
bool InitCUDA()
{
	int count;

	//ȡ��֧��Cuda��װ�õ���Ŀ
	cudaGetDeviceCount(&count);

	if (count == 0) {
		fprintf(stderr, "There is no device.\n");
		return false;
	}

	int i;

	for (i = 0; i < count; i++) {

		cudaDeviceProp prop;
		cudaGetDeviceProperties(&prop, i);
		//��ӡ�豸��Ϣ
		printDeviceProp(prop);

		if (cudaGetDeviceProperties(&prop, i) == cudaSuccess) {
			if (prop.major >= 1) {
				break;
			}
		}
	}

	if (i == count) {
		fprintf(stderr, "There is no device supporting CUDA 1.x.\n");
		return false;
	}

	cudaSetDevice(i);

	return true;
}


// __global__ ���� (GPU��ִ��) ����������
__global__ static void sumOfSquares(int* num, int* result, clock_t* time)
{
	int sum = 0;

	int i;

	clock_t start = clock();

	for (i = 0; i < DATA_SIZE; i++) {

		sum += num[i] * num[i] * num[i];

	}

	*result = sum;

	*time = clock() - start;

}





int main()
{

	//CUDA ��ʼ��
	if (!InitCUDA()) {
		return 0;
	}

	//���������
	GenerateNumbers(data, DATA_SIZE);

	/*�����ݸ��Ƶ��Կ��ڴ���*/
	int* gpudata, * result;

	clock_t* time;

	//cudaMalloc ȡ��һ���Կ��ڴ� ( ����result�����洢��������time�����洢����ʱ�� )
	cudaMalloc((void**)&gpudata, sizeof(int) * DATA_SIZE);
	cudaMalloc((void**)&result, sizeof(int));
	cudaMalloc((void**)&time, sizeof(clock_t));

	//cudaMemcpy ����������������Ƶ��Կ��ڴ���
	//cudaMemcpyHostToDevice - ���ڴ渴�Ƶ��Կ��ڴ�
	//cudaMemcpyDeviceToHost - ���Կ��ڴ渴�Ƶ��ڴ�
	cudaMemcpy(gpudata, data, sizeof(int) * DATA_SIZE, cudaMemcpyHostToDevice);

	// ��CUDA ��ִ�к��� �﷨����������<<<block ��Ŀ, thread ��Ŀ, shared memory ��С>>>(����...);
	sumOfSquares << <1, 1, 0 >> > (gpudata, result, time);


	/*�ѽ������ʾоƬ���ƻ����ڴ�*/

	int sum;
	clock_t time_used;

	//cudaMemcpy ��������Դ��и��ƻ��ڴ�
	cudaMemcpy(&sum, result, sizeof(int), cudaMemcpyDeviceToHost);
	cudaMemcpy(&time_used, time, sizeof(clock_t), cudaMemcpyDeviceToHost);

	//Free
	cudaFree(gpudata);
	cudaFree(result);
	cudaFree(time);

	printf("GPUsum: %d time: %d\n", sum, time_used);

	sum = 0;

	for (int i = 0; i < DATA_SIZE; i++) {
		sum += data[i] * data[i] * data[i];
	}

	printf("CPUsum: %d \n", sum);

	system("pause");

	return 0;
}
