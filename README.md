# Simulador de Escalonamento de Tarefas

Projeto prático da disciplina de **Sistemas Operacionais**, ministrada por
**Vinicius da Silva Borges**. Semestre **2/2026**.

Implementado em **Godot Engine** (GDScript).

## Autoria

- Gustavo Trindade Rodrigues
- Lucas Barboza Silva
- Matheus Henrique Gonçalves Nunes
- Victor Oliveira Malvão

## Descrição

Simulador do funcionamento de um escalonador de tarefas em um único processador.
A partir de um conjunto de tarefas definido pelo usuário (cada uma com instante
de ingresso, tempo de processamento e prioridade), o programa executa, tick a
tick, um dos seis algoritmos de escalonamento: FCFS, SJF, SRTF, Round-Robin,
Prioridade Cooperativa e Prioridade Preemptiva. O resultado é apresentado como
um diagrama de tempo, mostrando execução, espera, suspensão e conclusão de cada
tarefa.

O simulador também reproduz a disputa por um recurso de uso exclusivo (R),
permitindo observar a suspensão de tarefas, e oferece um modo de comparação que
executa os seis algoritmos simultaneamente sobre o mesmo conjunto de tarefas.

## Como executar

- Cique duas vezes em
  `<NomeDoExecutavel>.exe` ou
- Instale o [Godot Engine](https://godotengine.org/)
  (versão 4.4 ou superior), abra
  o projeto pela raiz do repositório e pressione **Play** (F5), tendo
  `TelaPrincipal.tscn` como cena principal.

## Estrutura do repositório

```
simulador_escalonamento/
|-- project.godot                          Arquivo de projeto do Godot Engine
|-- TelaPrincipal.tscn                     Cena principal (tela do simulador)
|-- Cena_Introdução.tscn                   Cena de abertura (animação de entrada)
|-- scenes/
|   `-- scripts/
|       |-- tela_principal_script.gd       Controlador raiz da tela principal
|       |-- cena_introdução_script.gd      Animação da tela de abertura
|       `-- log_script.gd                  Painel de histórico (log) da simulação
|-- elements/
|   |-- Elemento_Entrada_Texto.tscn        Campo numérico reutilizável (quantum, prioridade etc.)
|   |-- scripts/
|   |   |-- elemento_entrada_texto_script.gd
|   |   |-- elemento_grafico_script.gd     Motor de simulação (política + mecanismo)
|   |   |-- elemento_grafico_tupla_script.gd  Raia de uma tarefa no diagrama de tempo
|   |   `-- shader/
|   |       `-- crtvhs_screen_shader.gdshader  Efeito visual (cosmético) de CRT/VHS
|   |-- Lista de processos/
|   |   |-- tabela_de_processos.tscn       Tela de cadastro de tarefas
|   |   |-- Elemento_Tarefa_modulo.tscn    Cartão visual de uma tarefa cadastrada
|   |   `-- scripts/
|   |       |-- tabela_de_processos_script.gd
|   |       `-- elemento_processo_modulo_script.gd
|   `-- grafico/
|       |-- Elemento_Grafico.tscn          Aba de simulação de um único escalonador
|       |-- Elemento_Grafico_Mini.tscn     Versão compacta usada na comparação
|       |-- Elemento_multiplo_graficos.tscn  Aba de comparação dos seis escalonadores
|       |-- elemento_multiplo_graficos_script.gd
|       |-- tabela_resultados_script.gd    Tabela de métricas (turnaround, espera etc.)
|       |-- elemento_grafico_counter_script.gd  Régua de tempo do diagrama
|       |-- elemento_grafico_troca_script.gd    Raia de troca de contexto
|       |-- step_script.gd                 Célula visual de um tick (executando/vazio/suspenso)
|       `-- step_vazio.tscn, step_tarefa.tscn, step_tarefa_ativa.tscn, step_suspenso.tscn
|-- script/
|   `-- resource_processo_info_script.gd   Estrutura de dados de uma tarefa (TarefaInfo)
|-- resources/
|   |-- tarefainfo/                        Tarefas de exemplo (.tres)
|   `-- fonts/                             Fonte utilizada na interface
`-- assets/
    `-- textures/                          Imagens da interface
```

## Arquivos de código

| Arquivo | O que faz |
|---|---|
| `elements/scripts/elemento_grafico_script.gd` | Motor da simulação: laço de tempo (mecanismo) e os seis algoritmos de escalonamento (política) |
| `elements/scripts/elemento_grafico_tupla_script.gd` | Raia individual de uma tarefa no diagrama de tempo |
| `elements/grafico/elemento_grafico_troca_script.gd` | Raia de troca de contexto |
| `elements/grafico/elemento_grafico_counter_script.gd` | Régua de tempo (contador de ticks) do diagrama |
| `elements/grafico/step_script.gd` | Célula visual de um tick (executando, em espera, suspensa ou vazia) |
| `elements/grafico/tabela_resultados_script.gd` | Monta a tabela de métricas (turnaround, tempo de espera, tempo de resposta) |
| `elements/grafico/elemento_multiplo_graficos_script.gd` | Dispara e organiza a comparação simultânea dos seis escalonadores |
| `elements/Lista de processos/scripts/tabela_de_processos_script.gd` | Cadastro de tarefas: criação manual, aleatória, e persistência de cenários |
| `elements/Lista de processos/scripts/elemento_processo_modulo_script.gd` | Cartão visual de uma tarefa cadastrada |
| `script/resource_processo_info_script.gd` | Estrutura de dados de uma tarefa (`TarefaInfo`) e cálculo do tempo de espera |
| `elements/scripts/elemento_entrada_texto_script.gd` | Campo numérico reutilizável da interface |
| `scenes/scripts/tela_principal_script.gd` | Controlador raiz: conecta o botão "Iniciar" à aba de simulação ativa |
| `scenes/scripts/log_script.gd` | Painel de histórico textual da simulação |
| `scenes/scripts/cena_introdução_script.gd` | Animação da tela de abertura |

## Requisitos de ambiente

- **Godot Engine 4.4 ou superior** caso seja utilizado o código-fonte.
- Apenas classes nativas do motor.
- Sistema operacional: <preencher, conforme a(s) plataforma(s) de exportação usada(s)>.

## Funcionalidades

| O que faz | Onde |
|---|---|
| Algoritmos FCFS, SJF, SRTF e Round-Robin | `elements/scripts/elemento_grafico_script.gd` |
| Prioridade Cooperativa (não preemptiva) | `elements/scripts/elemento_grafico_script.gd` |
| Prioridade Preemptiva* | `elements/scripts/elemento_grafico_script.gd` |
| Diagrama de tempo (raias de execução, espera e suspensão) | `elements/scripts/elemento_grafico_tupla_script.gd`, `elements/grafico/elemento_grafico_troca_script.gd`, `elements/grafico/elemento_grafico_counter_script.gd` |
| Recurso de uso exclusivo (R) e suspensão de tarefas | `elements/scripts/elemento_grafico_script.gd` |
| Cadastro manual ou aleatório de tarefas, com salvar/carregar cenário | `elements/Lista de processos/scripts/tabela_de_processos_script.gd` |
| Comparação simultânea dos seis escalonadores | `elements/grafico/elemento_multiplo_graficos_script.gd` |
| Tabela de métricas por tarefa* | `elements/grafico/tabela_resultados_script.gd` |
| Log textual dos eventos da simulação | `scenes/scripts/log_script.gd` |

\* No estado atual do código-fonte, a Prioridade Preemptiva (com herança e teto de
prioridade) e o preenchimento automático da tabela de métricas ainda não estão
finalizados — ver `docs/documentacao_projeto.pdf` para o detalhamento técnico.

## Documentação

- [Tutorial de execução](./docs/tutorial_execucao.pdf)
- [Tutorial de uso](./docs/tutorial_uso.pdf)
- [Documentação técnica](./docs/documentacao_projeto.pdf)

## Por onde começar

1. Abra o programa e siga o tutorial de execução.
2. Reproduza um cenário de exemplo pelo tutorial de uso.
3. Consulte a documentação técnica para entender o funcionamento interno.
