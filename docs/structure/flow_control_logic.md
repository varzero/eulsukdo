# Flow Control Logic(FCL)
Flow Control Logic은  
명령의 흐름을 결정하기 위해 PC의 변화를 제어하고  
덮어 씌워져 더이상 사용되지 않는 내부 레지스터 번호를 반환하는 모듈입니다.  

![FCL 다이어그램](../img/8_FCL.JPG)

## 내부의 구성과 역할
### Flow Detect Unit(FDU)
명령 윈도우를 추적하고, 완료되면 더이상 사용되지 않는 내부 레지스터 번호를 반환하는 모듈이며,  
내부에 윈도우 범위 비교기와 FIFO를 가지고 있습니다.  
FCL 내부에 STRUCT_FLOW_WINDOWS 만큼 FDU가 있습니다.  

명령 윈도우를 추적하기 위해 시작 PC, 종료 PC, 실행된 명령의 수, 명령 윈도우가 가지는 명령의 갯수를 저장합니다.  
외부에서 종료 PC를 조작하여 명령 윈도우의 총 명령의 갯수를 업데이트하고,  
입력받은 완료된 명령의 PC가 명령 윈도우 내에 해당하는 명령인지 확인하고, 이에 따라 실행된 명령의 수를 업데이트 합니다.

### Calculate Next Program Counter
Program Counter를 조건에 따라 변경하고, 명령 윈도우를 생성하고 크기를 조정하는 로직입니다.  

조건에 따라 PC를 업데이트 하는 방법이 달라집니다.  
- *점프/분기 조건이 입력되지 않은 경우* <u>다음 명령의 PC로: 현재 명령 윈도우의 Flow Index와 현재 PC+```IS_INST_PC_STEP```를 전달</u>합니다.
    - 단, 명령 윈도우의 상한(```STRUCT_FLOW_PC_MAX_RANGE```)까지 사용된 경우 명령 윈도우는 새롭게 설정되고, 새롭게 설정된 Flow Index를 전달합니다.
- *명령을 통해 즉시 점프가 가능한 명령이 입력된 경우* <u>다음 명령의 PC로: 새로운 명령 윈도우의 Flow Index와 점프되는 PC를 전달</u>합니다. 이때 기존 명령 윈도우는 이전 명령까지 적용되도록 축소합니다.
- *레지스터 기반의 점프/분기 명령이 입력된 경우* <u>다음 명령의 PC로: 해당 명령이 완료되어 새로운 PC가 결정될 때까지 대기</u>합니다. 이때 기존 명령 윈도우는 이전 명령까지 적용되도록 축소합니다.

## 수신/송신하는 정보
### 다음 명령의 PC를 전달
#### 새로운 PC를 IM으로 전달
새로운 명령을 받기 위해 Instruction Memory(외부)에 새로운 명령의 Program Counter를 내보냅니다.

Calculate Next Program Counter에서 생성된 새로운 명령을 전달합니다.  
PC는 하나만 전달되며, Instruction Memory는 전달된 PC를 시작으로 연달아 연결된 STRUCT_DECODE_NEW_INST개의 명령을 NEL로 전달해야 합니다.

**Valid 기반 전송**을 사용합니다.  
배포용 소스 코드에서 명칭은 ```i/o_im_pc_*``` 입니다.

### 점프/분기 명령 여부 수신
#### PC제어 명령의 정보를 NEL에서 수신
Program Counter를 변경하는 명령정보를 받고, 해당 명령의 종류에 따라 특정한 동작이 되도록  
점프/분기/변경될 PC를 입력받습니다.  
(Calculate Next Program Counter를 제어)

**Valid 기반 전송**을 사용하는데, 다른 규격과 달리 주소와 플래그가 수신됩니다.  
- jump[0]: Immediate 값을 이용한 점프 명령 여부
- jump_reg[0]: 레지스터 값을 이용한 점프 명령 여부
- branch[0]: 분기 명령 여부
- new_pc[```IS_INST_BITWIDTH```-1:0]: 점프/분기로 변경되거나 변경될 수 있는 PC. *단, jump_reg 발생에서는 사용하지 않음*
딱 한세트만 전달되며,  
배포용 소스 코드에서 명칭은 ```i/o_nel_jump_branch_*``` 입니다.

### 완료된 명령들의 PC를 수신
#### 실행이 완료된 명령들의 Flow Index와 Program Counter를 WBC에서 수신
명령 윈도우의 관리를 위해 실행이 완료된 명령의 Flow Index와 Program Counter를 입력받습니다.  

실행이 완료된 명령 정보의 데이터 구조는 MSB부터 LSB 순서로 아래와 같고,
|Program Counter|Flow Index|
|-|-|
|[```_BITWIDTH_STRUCT_FLOW_WINDOWS```-1:0]|[```IS_INST_PC_BITWIDTH```-1:0]|

이 정보는 동시에 _STRUCT_EX_OUT_RESULT_ALL 만큼 수신할 수 있습니다.  
단, **첫번째 요소는 항상 분기 명령에 대한 요소**입니다.

**Valid 기반 전송**을 사용합니다.  
배포용 소스 코드에서 명칭은 ```i/o_wbc_pc_*``` 입니다.

#### 처리가 완료된 Branch 결과를 WBC에서 수신
Branch EX에서 출력된 결과를 FCL로 내보냅니다.  

데이터 구조는 MSB부터 LSB 순서로 아래와 같고,
|New Program Counter|Branch Active|
|-|-|
|[```IS_INST_PC_BITWIDTH```-1:0]|[0]|

이 정보는 **오직 하나입니다.**  

**Valid 기반 전송**을 사용합니다.  
배포용 소스 코드에서 명칭은 ```i/o_wbc_branch_*``` 입니다.  

### 덮어 씌워지는 내부 레지스터 번호를 수신
#### 특정 명령 이후에 사용되지 않는 내부 레지스터 번호를 NEL에서 수신
추후 명령 윈도우가 모두 처리되었을때 사용되지 않는 내부 레지스터 반환을 위해  
덮어 씌워지는 내부 레지스터 번호를 입력받습니다.

데이터 구조는 MSB부터 LSB 순서로 아래와 같고,
|Retired Physical Register Number|
|-|
|[```_BITWIDTH_STRUCT_PHYREGS```-1:0]|

이 정보는 동시에 STRUCT_DECODE_NEW_INST 만큼 수신할 수 있습니다.  

**Valid 기반 전송**을 사용합니다.  
배포용 소스 코드에서 명칭은 ```i/o_nel_unallo_reg_*``` 입니다.

### 사용 완료된 내부 레지스터 번호를 반환
#### 반환할 내부 레지스터 번호를 PRM에 전달
#### 반환되는 내부 레지스터 번호를 FCL에서 수신
더이상 사용되지 않는 내부 레지스터 번호를 내보냅니다.

데이터는 내부 레지스터 번호이며,  
이 정보는 동시에 STRUCT_UNALLOCATE_PHYREG 만큼 전달할 수 있습니다.  

**Valid 기반 전송**을 사용합니다.  
배포용 소스 코드에서 명칭은 ```i/o_prm_unallocate_*``` 입니다.
