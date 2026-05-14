# 을숙도 아키텍쳐 - EULSUKDO Archtecture
**슈퍼스칼라와 비순차 실행 처리를 위한 동적 스케줄링 구현체**
  
[중학생도 읽을만한 쉬운 대화형? 버전)](README_ez.md)
[English(use LLM translation)](README_en.md)
  
## 을숙도 아키텍처 프로젝트란?
이 프로젝트는 프로세서가 명령어를 처리하는 과정에서 
여러 명령을 동시에 처리**슈퍼스칼라**하고  
**순서와 상관없이 지금 바로 실행할 수 있는 명령을 즉시 처리**하는  
구조가 적용된 프로세서를 구현합니다.  

<u>**현재 작업중입니다.**</u>
```Plain-txt
상태 표시 방법
  v 완료 (검증까지)
  ? 검증되지 않음
  - 내용 작성중
  x 시작되지 않음

[현재 작업 현황]
README
  v 배경 설명부분
  - 전체 다이어그램: 현재 다이어그램은 FCL, WBC가 반영되지 않은 버전
  v 각 모듈별 설명
  x 타 아키텍쳐와 비교 분석
  - 진지하게 다시 쓰기
CODE-Memory and Position Splitter or FIFO Element
  v Memory
  v Position Splitter
  v FIFO
  v Multi_data i/o FIFO
  v Allocator
  v Allocator, Value Start 1
CODE-Architecture
  v Rv32I Decoder and IMM
  ? NEL
  ? IST
  ? PRM
  ? RS
  ? WBC
  ? FCL
  x Top Module
```

### 메인 알고리즘: 토마슬로 알고리즘
명령의 레지스터 체계를 프로세서에서 내부적으로 바꿔 처리하는 **레지스터 리네이밍**을 핵심적으로 사용하고  
알고리즘의 주요 컨셉인 **명령의 상태를 이용**하는 방법을 내부적인 회로로 나누는 구조를 채택합니다.  

## 
토마슬로 알고리즘이 추구하는 **레지스터 이름 변경**을 적용한  
**비순차 실행 처리를 진행하는 동적 스케줄링 구조**를 만드는것이 최종적인 목표입니다.
이때, 전력 소모를 줄이기 위해 CAM이라는 구조를 배제하여 구현해보았습니다.

특히 명령의 레지스터 체계를 바꾸어, 기존에 이름이 겹쳤던 부분을 해소하고자 합니다!

### 그렇다면 너의 구조는 어떻게 생겼어?
제 구조는 크게 4개의 구역으로 나눌수 있는데,
1. 새롭게 들어온 명령을 해석하고 새로운 레지스터 체계로 바꾸는 부분
2. 현재 명령들의 상태를 기록해 두고, 실행할 준비가 된 명령을 연산/메모리접근 부분으로 넘겨주는 부분
3. 바뀐 레지스터 체계를 기준으로, 해당 레지스터가 사용되는 명령을 저장하고, 상태를 변경하는 부분
4. 현재 명령의 순서와 수행된 명령을 확인하여 지울수 있는 레지스터를 제거(할당 취소)하는 부분

으로 나눌 수 있어요.

그래서, 이를 구현하기 위해 6개의 모듈로 나누었습니다.
- New Entry Logic
- Instruction State Table
- Physical Register Mapper
- Ready Station
- Write Back Concatenation
- Flow Control Logic

자세히 설명해볼까요?  

일단 전체 구조는 아래와 같아요  

**현재, Write Back Concatenation와 Flow Control Logic이 제대로 표현되지 않은 이전버전입니다.**

![다이어그램](Diagram.png)

#### New Entry Logic(NEL)
**새롭게 들어온 명령을 해석하고 새로운 레지스터 체계로 바꾸어 주는 모듈**입니다!  

이 모듈은 *Instruction Memory*, **Instruction State Table**, **Physical Register Mapper**, **Write Back Concatenation**, **Flow Control Logic**과 연결되어 있습니다.
```Plain-text
Instruction Memory
[받는 정보]
 - 새로운 명령

Instruction State Table
[보내는 정보]
 - 내부 처리용으로 변경되고 새로운 레지스터 체계로 바뀐 명령

Physical Register Mapper
[받는 정보]
 - 새로운 레지스터 체계의 비어있는 레지스터 번호

Write Back Concatenation
[받는 정보]
 - 처리가 완료된 레지스터 번호

Flow Control Logic
[보내는 정보]
 - Jump, 분기 명령어 여부 전달
 - 덮어 씌워지는 명령 레지스터가 할당되었던 기존 레지스터 번호
```

내부에 명령 레지스터 번호와 변경된 레지스터 체계에서의 번호간의 매핑과 준비 상태를 기록해둔 **Register File**이 있습니다.

#### Instruction State Table(IST)
**현재 명령들의 상태를 기록해 두고, 필요시 상태를 변경하며, 실행할 준비가 된 명령을 알리는 모듈**입니다!  

이 모듈은 **New Entry Logic**, **Physical Register Mapper**, **Ready Station**과 연결되어 있습니다.
```Plain-text
New Entry Logic
[받는 정보]
 - 내부 처리용으로 변경되고 새로운 레지스터 체계로 바뀐 명령

Physical Register Mapper
[보내는 정보]
 - 새로운 레지스터 체계로 바뀐 명령에서 필요한 레지스터 번호와 IST 번호
[받는 정보]
 - 상태가 변경되는 IST 번호와 변경시킨 레지스터 번호

Ready Station
[보내는 정보]
 - 준비가 완료된 명령
```

내부에 명령과 상태를 저장해두는 **Register File**이 있고, 이 Register File의 엔트리를 할당하는 **allocator**가 있습니다.  

#### Physical Register Mapper(PRM)
**바뀐 레지스터 체계를 기준으로, 해당 레지스터가 사용되는 명령을 저장하는 모듈**입니다!  

이 모듈은 **New Entry Logic**, **Instruction State Table**, **Write Back Concatenation**, **Flow Control Logic**과 연결되어 있습니다.
```Plain-text
New Entry Logic
[보내는 정보]
 - 새로운 레지스터 체계의 비어있는 레지스터 번호

Instruction State Table
[받는 정보]
 - 새로운 레지스터 체계로 바뀐 명령에서 필요한 레지스터 번호와 IST 번호
[보내는 정보]
 - 상태가 변경되는 IST 번호와 변경시킨 레지스터 번호

Write Back Concatenation
[받는 정보]
 - 처리가 완료된 레지스터 번호

Flow Control Logic
[받는 정보]
 - 이후에 사용되지 않을 레지스터 번호
```

내부에 특정 레지스터가 사용하는 IST의 주소와 갯수가 저장된 **Register File**이 있고, 새로운 체계의 레지스터 번호를 할당하는 **allocator_start_one**(레지스터 0번은 "0" 값으로 고정할거거든요)가 있습니다.

#### Ready Station(RS)
**실행할 준비가 된 명령을 연산/메모리접근 부분으로 넘겨주는 모듈**입니다!  

이 모듈은 **Instruction State Table**, *Execution Unit으로 통칭되는 연산/메모리 접근/명령순서 제어부*와 연결되어 있습니다.
```Plain-text
Ready Station
[받는 정보]
 - 준비가 완료된 명령 

Execution Unit으로 통칭되는 연산/메모리 접근/명령순서 제어부
[보내는 정보]
 - 준비가 완료되어 처리를 기다리는 명령
```

내부에 RS로 입력받아 처리를 기다리는 명령을 저장해둔 **FIFO**가 있습니다.

#### Write Back Concatenation(WBC)
**처리가 완료된 명령의 정보를 전달하는 모듈**입니다!  

이 모듈은 *Execution Unit으로 통칭되는 연산/메모리 접근/명령순서 제어부*, **Physical Register Mapper**, **New Entry Logic**, **Flow Control Logic**과 연결되어 있습니다.
```Plain-text
Execution Unit으로 통칭되는 연산/메모리 접근/명령순서 제어부
[받는 정보]
 - 처리가 완료된 명령의 주소(PC) 및 레지스터 번호와 결과의 일부
   (Branch의 경우 새롭게 가져올 명령어의 주소:PC)
 
Physical Register Mapper
[보내는 정보]
 - 처리가 완료된 레지스터 번호

New Entry Logic
[보내는 정보]
 - 처리가 완료된 레지스터 번호

Flow Control Logic
[보내는 정보]
 - 처리가 완료된 명령어 주소
```

이건 EX의 출력에서 레지스터 번호들을 묶어 외부로 전달합니다. Branch EX등 특수목적 EX에는 추가 값을 따로 떼서 외부로 전달하기도 해요.

#### Flow Control Logic(FCL)
**현재 명령의 순서와 수행된 명령을 확인하여 지울수 있는 레지스터를 제거(할당 취소)하는 모듈**입니다!  

이 모듈은 **New Entry Logic**, **Physical Register Mapper**, **Write Back Concatenation**, *Instruction Memory*와 연결되어 있습니다.
```Plain-text
New Entry Logic
[받는 정보]
 - Jump, 분기 명령어 여부 전달
 - 덮어 씌워지는 명령 레지스터가 할당되었던 기존 레지스터 번호
 
Physical Register Mapper
[보내는 정보]
 - 이후에 사용되지 않을 레지스터 번호

Write Back Concatenation
[받는 정보]
 - 처리가 완료된 명령어 주소

Instruction Memory
[보내는 정보]
 - 새롭게 가져올 명령어의 주소:PC
```

내부에는 레지스터 반환을 위한 구조가 여러개 배치되어 있는데, 그 구조를 설명하자면  
PC의 시작값/마지막값을 저장하는 레지스터와 그 사이에 몇개의 명령이 처리되었는지 카운팅 하고, 그 사이에서 덮어 쓰여진 레지스터들의 번호를 저장해 둔 **FIFO**가 있습니다.  
PC의 시작값-마지막값 사이에 모든 명령이 완료된다면, 그 부분의 FIFO에 저장되었던 레지스터 번호들을 PRM으로 보내서 반환 시켜버리고, 해당 부분을 초기화 시켜 새로운 PC의 시작값-마지막값으로 할당할 수 있도록 합니다.  
이때 시작값-마지막값이 제법 클수 있으니 제한으로 레지스터 체계에서 사용가능한 레지스터 숫자의 절반까지(예를들어 레지스터가 최대 64개라면 32개까지) 명령의 PC의 범위를 지정할 수 있도록 합니다.

### 특별해 보이는 모듈이 있는데, position_splitter? fifo_ordering_position? allocator? 이거 뭐야?
이번 프로세서를 구현하면서 디지털 회로로 정렬기를 만들었는데, 그게 position_spliter입니다.  
이 회로를 사용해서, 최대 m개의 입력과 최대 n개의 출력이 가능한 가변 입출력 FIFO를 만들었고,  
이 구조를 이용해서 하드웨어적으로 할당/반환기를 만들었습니다.  
이것들이 각각 fifo_ordering_position, allocator 입니다.  

#### position_splitter
이 모듈은 정렬되지 않은 위치로 입력되는 최대 n개의 데이터를 LSB 방향으로 모아 출력합니다.  
입력으로 최대 n개의 데이터가 들어올 수 있고, 유효한 데이터 위치를 나타내는 n비트의 Valid 신호를 입력받습니다.  
출력으로 최대 n개의 LSB 방향으로 정렬된 데이터가 출력되고, 유효한 데이터 위치를 나타내는 n비트의 Valid 신호를 출력합니다.  

#### fifo_ordering_position
이 모듈은 정렬되지 않은 위치로 입력되는 최대 m개의 데이터를 저장하고,  
LSB 방향으로 모아 정렬된 n개의 데이터를 출력하는 **FIFO Memory** 입니다.  
입력으로 최대 m개의 데이터가 들어올 수 있고, 유효한 데이터 위치를 나타내는 m비트의 Valid 신호를 입력받습니다.  
출력으로 LSB 방향으로 정렬된 최대 n개의 저장된 데이터가 출력되고, 유효한 데이터 위치를 나타내는 n비트의 Valid 신호를 출력합니다.  
가져간 데이터를 나타내기 위해서는 가져갈 비트가 활성화된 n비트의 get 신호를 전달하면 됩니다.  
다음 사이클에서 가져가지 않은 데이터는 재정렬되고 저장되었던 데이터가 뒤쪽으로 채워져서 출력됩니다.  

#### allocator, allocator_start_one
이 모듈은 하드웨어적으로 구현된 숫자 할당/반환기이며, 최대 n개의 숫자를 할당하고 최대 m개의 숫자를 반환할 수 있습니다.  
입력으로 최대 m개의 숫자를 반환할 수 있고, 반환할 숫자의 위치를 나타내는 m비트의 Valid 신호를 입력받습니다.  
출력으로 할당할 수 있는 LSB 방향으로 정렬된 최대 n개의 숫자가 출력되고, 할당 가능한 숫자의 위치를 나타내는 n비트의 Valid 신호를 출력합니다.  
할당하기 위해서는 가져갈 비트가 활성화된 n비트의 get 신호를 전달하면 됩니다.
allocator는 0부터, allocator_start_one는 1부터 할당됩니다!

## 이 저장소는 어떻게 봐야돼?
제가 열심히 만들어 둔 베릴로그 코드를 보셔야죠.  
그러기 위해서 저는 디렉토리를 아래와 같이 나눴어요.  
```Plain-text
RTL/ : 베릴로그로 작성된 RTL 코드들이 있어요
    RTL/1decode3issue : 힌번에 최대 하나의 명령을 해석하고, 
                        3가지 동작 산술과 논리연산/메모리 접근/브랜치 결정을 동시에 진행할 수 있습니다.
                        이 구조로 작성된 코드가 있는 디렉토리입니다.
TB/  : RTL/의 모듈들을 검증하기 위한 Testbench가 있는 디렉토리 입니다.
```

### 을숙도 아키텍쳐의 ISA: RV32I
[RISC-V ISA 저장소](https://github.com/riscv/riscv-isa-manual)  
을숙도 아키텍쳐는 U

### 사족
저는 개인 프로젝트에 진지하게 쓰는것을 딱히 좋아하지 않습니다.  
그래서 오히려 아래 부분이 더 구체적이고 제가 추구하는 방향성이 가득 들어 있습니다.  
[중학생도 읽을만한 쉬운 대화형? 버전)](README_en.md)
