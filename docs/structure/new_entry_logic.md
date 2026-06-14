# New Entry Logic(NEL)
New Entry Logic는  
새로운 명령을 입력받아, 이때 명령의 레지스터들을 내부 체계의 이름으로 변경하며,  
새로운 명령에서 필요한 레지스터의 준비여부를 모아 내부에서 처리하는 명령 체계로 변환합니다.

![NEL 다이어그램](../img/3_NEL.JPG)

## 내부의 구성과 역할
### 설계자 정의 ISA 디코더
을숙도 아키텍쳐는 설계자가 원하는 형태의 Instruction Set을 사용할 수 있습니다.  
다만, 몇가지 조건이 있습니다.  
- 고정 길이 명령 구조만 사용할 수 있습니다.
- 명령을 구분하는 PC 값의 단위가 반드시 동일하게 구분되어야 합니다.

설계자가 사용할 수 있는 디코더의 입출력 포맷이 고정되어 있습니다.  

명령을 처리하기 위해 설계자가 정의 하는 ISA 디코더는    
입력으로
|Name|Bit-Width|Description|
|-|-|-|
|inst|```IS_INST_BITWIDTH```|Instruction Set 기반의 명령|

을 받고,   

출력으로  
|Name|Bit-Width|Quantity|Description|
|-|-|-|-|
|EX_PATH|BIT_WIDTH(```STRUCT_EX_PATH```)|1|EX 종류 지정|
|Micro-OP|```EX_INST_MICROOP```|1|EX용 Opcode|
|RD|BIT_WIDTH(```IS_INST_REGS```)|1|Register Destination|
|Allocate_NEW_RD|1|1|명령이 레지스터를 수정하는지 여부|
|RS|BIT_WIDTH(```IS_INST_REGS```)|```IS_INST_OPERANDS```|Register Sources|
|RS_use|1|```IS_INST_OPERANDS```|사용하는 Register Source 필드|
|Jump|1|1|PC의 값을 레지스터 없이 변경하는 명령 여부, 다음 명령을 불러오는 경우는 포함하지 않음|
|Jump_Reg|1|1|PC의 값을 레지스터를 이용하여 변경하는 명령 여부|
|Branch|1|1|PC의 값을 조건에 따라 변경하는 명령 여부|

가 출력되게 만드셔야 합니다.   
이 디코더는 총 ```STRUCT_DECODE_NEW_INST```개 만큼 존재하게 됩니다.

BIT_WIDTH(```인자```)는 인자의 log2에서 소수점 아래 값이 있을때 올림한 값입니다.  

위와 같은 형태를 맞춰 <u>설계자 정의 ISA 디코더</u>를 설계한다면,  
제공하는 생성기로 바로 을숙도 아키텍쳐에서 사용할 수 있습니다.  

### ISA Register <-> Physical Register Mapping Table
Instruction Set Architecture에 정의 된 레지스터와 내부 레지스터 간의 매핑 관계를 저장하는 Register File입니다.  
Register File의 주소로 **Instruction Set 레지스터 번호**를 사용하고,  
Register File의 데이터로 **내부 레지스터 번호**를 저장합니다.  

이 Register File 입출력 채널의 구성으로  
- 입력 채널 갯수: ```STRUCT_DECODE_NEW_INST```
    - 아래부터 명령의 PC 값 순서로 전달하여  
    *입력되는 가장 낮은 PC의 명령 RD 레지스터 번호, ... , 입력되는 가장 높은 PC의 명령 RD 레지스터 번호* 형태의 주소를 사용하고,  
    동일한 형태로 **재할당된 레지스터 필드의 위치**(Write Enable)과 **매핑할 레지스터 값을 데이터로 입력**합니다.
- 출력 채널 갯수: ```(STRUCT_DECODE_NEW_INST*(1+IS_INST_OPERANDS))```
    - <u>명령의 RD 레지스터 번호, 명령의 RS_1 레지스터 번호, ... , 명령의 RS_n 레지스터 번호</u> 묶음을  
    아래부터 명령의 PC 값 순서로 전달하여  
    *[ (Inst ```1```)RD, RS_1, ... , RS_n ] ~~~ [ (Inst ```STRUCT_DECODE_NEW_INST```)RD, RS_1, --- , RS_n ]* 형태의 주소를 사용하고,  
    동일한 형태로 **매핑 된 레지스터 값이 데이터로 출력**됩니다.  

### Physical Register Ready Table


### Decode


## 수신/송신하는 정보
많은 부분에서 Handshake/Valid 구조를 이용하였기 때문에,  
해당 모듈에서 크게 수신과 송신으로 표현하여 설명합니다.
다이어그램에서 왼쪽 위 부터 시계방향으로 설명합니다.  
동작 실증용 코드와 배포용 소스 코드에서 다른 명칭을 사용하였기에  
세부적인 각 신호의 이름은 *동작 실증용 코드에서 명칭*/*배포용 소스 코드에서 명칭*으로 표현합니다.

### 사용 가능한 레지스터 번호를 PRM에서 수신
새로운 명령에서 레지스터 쓰기가 발생한다면, *레지스터 리네이밍*을 위해 새로운 레지스터를 할당받습니다.  
이 정보는 동시에 DECODE_NEW_INST 만큼 수신할 수 있습니다.  
- (입력) PRM의 동작 가능 상태: Active/
- (입력) PRM에서 할당하는 레지스터의 유효성 정보: Valid/ 
- (입력) PRM에서 할당하는 레지스터의 번호: Phyreg
- (출력) PRM에서 가져올(할당받을) 레지스터 번호의 위치: Allocate Position/get_reg 

동작 실증용 코드에서 명칭은 ```o_allocate_position```, ```i_prm_active```, ```i_prm_allocate_*``` 입니다.  
배포용 소스 코드에서 명칭은 ```i/o_prm__*``` 입니다.

### 새로운 명령을 외부에서 수신
새로운 명령을 받아들이기 위해 3가지를 정보를 받아들입니다.  
이 정보는 동시에 DECODE_NEW_INST 만큼 수신할 수 있습니다.  
- (입력) 새로운 명령의 유효성 정보: Valid
- (입력) 새로운 명령의 번호: PC
- (입력) RV32I 기반의 새로운 명령: Inst
- (출력) NEL이 수신할 수 있는 명령 위치: Get

동작 실증용 코드에서 명칭은 ```i/o_im_inst_*``` 입니다.  
배포용 소스 코드에서 명칭은 ```i/o_im_inst_*``` 입니다. 

### 내부 체계로 변경된 명령어 코드를 IST로 전달
새로운 명령을 받아들이기 위해 3가지를 정보를 동시에 받아들입니다.  
이 정보는 동시에 DECODE_NEW_INST 만큼 전달할 수 있습니다.  
- (입력) IST의 입력 가능 상태: Insert Available
- (출력) 

동작 실증용 코드에서 명칭은 ```i_ist_insert_avaliable```, ```i/o_ist_field_*``` 입니다.   
배포용 소스 코드에서 명칭은 ```i/o_ist_*``` 입니다.






## 데이터 흐름과 예시
