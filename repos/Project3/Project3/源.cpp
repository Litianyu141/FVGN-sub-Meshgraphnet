#include <iostream>
#include<math.h>
using namespace std;

class printData
{
public:
    void print(int i) {
        cout << "����Ϊ: " << i << endl;
    }

    void print(double  f) {
        cout << "������Ϊ: " << f << endl;
    }

    void print(char c[]) {
        cout << "�ַ���Ϊ: " << c << endl;
    }
};

int main(void)
{
    double b = INFINITY;
    float a = 0;
      if (isinf(a));
      cout << "no" << endl;
    printData pd;

    // �������
    pd.print(5);
    // ���������
    pd.print(500.263);
    // ����ַ���
    char c[] = "Hello C++";
    pd.print(c);

    return 0;
}