# Native AI 技术整合

整合日期：2026-10-15。材料来自 `docs/switch-native-ai.md` 里已经核对过的公开文档。这里不再按厂商复述，而是按计算发生的位置，把四家的相关技术收成三条链。

Native 只表示计算发生在交换机的操作系统、交换芯片或板载 CPU/GPU 上。控制器、分析云和网卡上的模型不算交换机原生。

## 结论

四家对外都叫 AI，实际只有一条链把神经网络留在交换机里：华为 CloudEngine 数据中心交换机的 EAI 框架，加上订阅它的 AI ECN。

其余能力分成两条。一条是交换机产出特征或计数，学习在控制器和云上完成。另一条是交换机自己执行的拥塞控制和负载均衡，公开文档写成算法，不是可加载的模型。

## 三条链

```text
流量
  |
  +-- 链 1  交换机内闭环
  |     华为 EAI 加载模型，AI ECN 改无损队列的 ECN 阈值
  |     HPE NAE 在本机做统计基线、告警和脚本动作
  |
  +-- 链 2  交换机出数，外部学习
  |     Cisco：SPLT/IDP、NBAR
  |     Arista：SysDB 状态流、100 微秒 ECMP 计数
  |     HPE：CX 遥测、Junos CloudX
  |         |
  |         +--> Secure Network Analytics、Catalyst Center、Nexus Dashboard
  |         +--> CloudVision AVA / CV UNO
  |         +--> Mist、Aruba Central
  |
  +-- 链 3  为 AI 训练网服务的本机转发算法
        阈值、降速、选路、链路重传
        执行点在芯片和交换机操作系统，不加载神经网络
```

链 1 和链 3 都在设备上跑，但只有链 1 的华为 EAI 符合“原生模型推理”。链 2 才是各家自然语言助手、异常检测和根因分析的所在。

## 链 1：交换机内闭环

| 技术 | 厂商与平台 | 输入 | 本机计算 | 动作 |
| --- | --- | --- | --- | --- |
| EAI | 华为 CloudEngine 9800/8800/6800/16800、XH16800 | 模型文件，加上业务订阅的流量特征 | 已知场景用神经网络推理；未知场景用 BBR 启发式搜索 | 把推理结果交给订阅的 AI 业务 |
| AI ECN | 同上，许可项 `CE-LIC-AFRD` | 无损队列的队列长度等流量特征 | 调用 EAI。显示结果分 NN、BBR、STATIC | 改该队列的 ECN 低阈值、高阈值和标记概率 |
| NAE Baseline | HPE Aruba CX，AOS-CX 10.1 起。10.14 指南覆盖 6200、6300、6400、8100、8320、8325、8360、8400、9300、10000 | 代理监测的交换机指标 | MaxAlgorithm：学习窗口内平滑，再用高、低倍率形成动态阈值。尖峰不写回基线 | 告警，并可执行代理里定义的纠正动作 |

EAI 是框架，不是某一个功能。设备自带默认模型，不能卸载，最多再加载 20 个模型文件。AI ECN 是目前文档写清楚的订阅者。模型包括集中式计算、分布式存储、分布式文件存储、高性能计算和通用计算；未指定时默认分布式存储。CE16800 的模型命令限于 J、J2、P、SAN 系列板卡。

NAE 的其余部分是规则引擎：监测配置与状态数据库、保存时间序列、把配置变更和随后的状态变化关联起来。10.10 起可以用 NAE-Lite 在命令行建代理。它不加载可更换的神经网络。

园区 CloudEngine S 配置里的 EAI 是 Egress ARP Inspection，按 DHCP Snooping 绑定表转发 ARP。它和数据中心的嵌入式人工智能同名，不是这条链上的技术。

Cisco C9350-48HXG 有 8 核 CPU 和集成 GPU。数据手册写的是硬件已准备好承担较小的盒内推理，没有给出随软件交付的模型、输入和动作，所以不能放进这张表。

## 链 2：交换机出数，外部学习

交换机在这条链上是传感器。下表左边是本机能力，右边才是模型或助手。

| 交换机上发生的事 | 送出去的数据 | 学习和动作所在 |
| --- | --- | --- |
| Catalyst 9300/9400 的 Encrypted Traffic Analytics，从 IOS XE 16.8.1a 起 | 每条流的序列包长和时间，以及初始数据包。规模约每秒 2000 流 | Secure Network Analytics 做多层统计学习，判断加密流量里的恶意软件和加密合规。IOS XE 文档中的 “machine learning” 指的是这条外部分析 |
| Catalyst 9000 的 NBAR，IOS XE 17.6 起供数 | 深度包检测得到的应用和终端遥测 | Catalyst Center 及 Cisco 云上的 AI Endpoint Analytics：画像、智能分组、仿冒检测 |
| 交换机流式遥测、NetFlow | 设备、接口、流和客户端指标 | Catalyst Center 的 AI Network Analytics 学习本网正常行为；AI Assistant 用自然语言查询这些结果 |
| N9000 遥测，包括 RoCEv2 的 ECN 和 PFC 计数 | 接口、流、以及 Dashboard 4.3.1 起关联的 GPU 和服务器网卡统计 | Nexus Dashboard Insights 做基线、异常关联和预测。大模型通过 Dashboard 上的 MCP 连接，不在交换机上 |
| EOS SysDB 状态流，NetDL Streamer | 设备状态、协议、接口和事件的时间序列 | CloudVision AVA：异常、逐跳关联、处置建议。Ask AVA 是其上的自然语言入口 |
| 7060XE7 AI Analyzer | ECMP 成员利用率，聚合粒度可以到 100 微秒 | 本机结果用于动态负载均衡；跨作业分析由 AVA 和 CV UNO 完成 |
| 远端 EOS AI Agent | SuperNIC 或服务器遥测 | 送进 NetDL。代理不在交换机 ASIC 上 |
| AOS-CX 与 Junos CloudX 的遥测。CloudX 含 Mist Cloud Daemon 和 Junos Mist Daemon | 端口、客户端、交换机健康和事件 | Mist 与 Aruba Central。Marvis 做服务等级、坏线缆、协商不匹配、VLAN 缺失和生成树环路等判断，并可以执行受控动作，例如有线口修复 |

这解释了为什么 Cisco、Arista、HPE 的发布会都在讲 AI 助手，而交换机配置手册里找不到对应的模型加载命令。助手消费的是链 2 的数据。

## 链 3：本机转发算法

这些技术和 AI 训练流量放在同一套方案里，名称也常带 AI 或 Smart AI。它们根据队列、链路利用率和拥塞信号改转发行为，文档没有把它们写成神经网络。

| 要解决的问题 | 华为 | Cisco | HPE | Arista |
| --- | --- | --- | --- | --- |
| 无损队列何时标记拥塞 | AI ECN，属于链 1 | 静态或常规 ECN，学习不在交换机 | 常规无损以太网能力 | PFC 感知的 ECN |
| 让源端更快降速 | iQCN 主动发 CNP；NPCC 做网络侧拥塞控制。二者互斥 | Nexus 侧可见 ECN/PFC，决策不在这条链 | 公开的交换机文档没有对等的主动 CNP 模型 | Fast CNP、增强 DCQCN、CSIG |
| AI 集合通信的选路和均衡 | NSLB、Flow Matrix、Rail Group；Dragonfly 与 Graceful Adaptive Routing | N9000 / Silicon One 的负载均衡和缓冲，随平台而异 | QFX 面向推理和横向扩展的组网，算法细节不在本次交换机原生清单里 | CLB 面向 RDMA；DLB 按实时链路负载改流 |
| 单链路故障不要拖停整个作业 | 自适应路由避开拥塞链路 | 随 NX-OS 平台的等价和自适应转发 | 未在本次清单中单列为模型 | MRC，配合链路层重传 |
| 短时突发是否被传统计数器漏掉 | 遥测和队列特征供 EAI 使用 | 遥测导出 | NAE 时间序列，粒度是监控代理而不是微秒级 ECMP | AI Analyzer，100 微秒 |

华为把链 3 里的 iQCN、NPCC 和链 1 的 AI ECN 放在同一个 AI 业务视图，许可上也常一起出现在 N1 Premium。视图相同，不表示算法相同。iQCN 是判断拥塞后主动发 CNP，NPCC 是高吞吐或低时延两种工作模式，都没有写成神经网络。

Arista 的 CLB、DLB、MRC 属于 EOS Smart AI 套件，执行点是 EOS 和交换芯片。2025 年 3 月 CLB 先出现在 7260X3、7280R3、7500R3、7800R3。7060XE7 在 2026 年把 DLB、CLB、MRC、CSIG、Fast CNP 列为 AI 以太网特性。

## 同一问题该看哪一条链

| 问题 | 看哪一条链 | 直接对应的技术 |
| --- | --- | --- |
| 交换机能不能自己加载模型并改转发参数 | 链 1 | 只有华为 EAI 与 AI ECN |
| 交换机能不能自己学出阈值并告警 | 链 1 | HPE NAE Baseline，统计方法，不是神经网络 |
| 加密流量、终端和应用的智能判断在哪 | 链 2 | Cisco ETA 与 NBAR 只负责特征；判断在 Secure Network Analytics 和 Catalyst Center |
| 全网异常、根因和自然语言问答在哪 | 链 2 | Catalyst Center、Nexus Dashboard、Mist / Marvis、Aruba Central、CloudVision AVA |
| AI 作业为什么慢、哪条链路在拥塞 | 链 2 加链 3 | Arista 用 AI Analyzer 和 CV UNO；Cisco 用 Nexus Dashboard 关联 GPU、交换机和网卡；华为用 FabricInsight，不在交换机上 |
| 训练网如何少丢包、少长尾 | 链 3 | 四家都有无损以太网和动态均衡。其中只有 AI ECN 的阈值来自本机模型 |

## 命名上容易并到错误的链

- 华为园区 EAI 不是嵌入式人工智能。
- AI Fabric、Smart AI、AI Analyzer 这些产品名，多数落在链 3 或链 2，不自动等于链 1。
- “网络服务 AI”和“交换机运行 AI”是两件事。链 3 解决的是前一件。
- C9350-48HXG 的 GPU 是链 1 的硬件预备，不是已交付的推理功能。
- 远端 EOS AI Agent 在 SuperNIC 或服务器上，不因为名字里有 EOS 就算交换机原生。
