# App搭建与运行

装配步骤见[第15步STEPS第7节](../../../../lib/MTPA弱磁/build_process/STEPS.md#7-接入整机与转矩pi)，运行/调参见[USAGE](../../../../lib/MTPA弱磁/build_process/USAGE.md)。组件内部公式和状态实现属于[lib/mtpa_fw](../../../../lib/MTPA弱磁/build_process/DESIGN.md)。

本App的src只放整机模型。PostLoadFcn先加入docs/scripts，调用initialize_motor_paths，再复用lib中的initialize_mtpa_fw_model。共享路径函数不会改库的算法或参数默认值。

[返回模块](../README.md)
