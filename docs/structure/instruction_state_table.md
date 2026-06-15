# Instruction State Table(IST)
Instruction State Table은  
입력된 명령에서, 준비된 명령은 처리할 수 있도록 전달하고,  
아직 준비되지 않은 명령은 대기하는 모듈입니다.

![IST 다이어그램](../img/4_IST.JPG)

## 내부의 구성과 역할
### Instruction State Entry Number Allocator
Instruction State Table의 Entry를 할당하기 위한 Entry 번호 Allocator입니다.  

이 Allocator는 Instruction State Table의 Entry 번호를 출력하고, 사용이 완료된 Entry 번호를 입력받습니다.  
BIT_WIDTH(```IS_INST_REGS```)만큼의 너비를 가집니다  

BIT_WIDTH(```인자```)는 인자의 log2에서 소수점 아래 값이 있을때 올림한 값입니다.  

### Instruction Entry Table
대기하는 명령을 저장하는 Register File입니다.  


### Instruction Source Table
대기하는 명령이 필요한 내부 레지스터 번호를 저장하는 Register File입니다. 

### Ready Flags Table
대기하는 명령에서 준비된 내부 레지스터의 Ready Flag를 저장하는 Register File입니다. 

