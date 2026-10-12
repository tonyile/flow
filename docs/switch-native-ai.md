# 主力交换机原生 AI 功能收集

收集日期：2026-10-12。对象是华为 CloudEngine、Cisco Catalyst / N9000、HPE Aruba CX 与 HPE Juniper、Arista EOS。材料来自各厂商公开配置指南、数据手册和新闻稿，不是实验室实测，也不是按具体订单的许可矩阵。

这里的“原生”只指推理或自适应计算发生在交换机自身的操作系统、交换芯片或板载 CPU/GPU 上。控制器、分析器和分析云上的 AI 单独列出，避免和本机功能混在一起。

面向 AI 训练的无损以太网、动态负载均衡、拥塞通知，很多被放进 “AI Fabric” 或 “Smart AI” 套件。公开文档把它们写成拥塞控制或调度算法，没有写成神经网络。下文把这类能力标成“智能算法”，不标成模型推理。

## 总表

| 厂商 | 本机模型推理 | 本机自适应或智能算法 | 推理实际所在的控制器或云 |
| --- | --- | --- | --- |
| 华为 | CloudEngine 数据中心交换机的 EAI（嵌入式人工智能）框架，以及订阅该框架的 AI ECN | iQCN、NPCC，以及 iNOF、NSLB、自适应路由等智能无损特性 | iMaster NCE-Fabric、iMaster NCE-FabricInsight |
| Cisco | 没有跨 Catalyst / N9000 通用、已出货的命名模型。C9350-48HXG 具备板载 GPU，数据手册写的是“硬件已准备好做较小规模的盒内推理” | 交换芯片提取加密流元数据；NBAR 做深度包检测；AI 以太网拥塞与负载均衡在芯片和 NX-OS 上执行 | Secure Network Analytics、Catalyst Center、Meraki、Nexus Dashboard |
| HPE | 没有公开的盒内神经网络。AOS-CX NAE 在交换机上做规则监控，并用统计基线动态调阈值 | NAE / NAE-Lite 的监测、关联、脚本化动作；Junos 上的 CloudX 只负责把遥测送到云 | Aruba Central、Mist（Marvis）、Data Center Director |
| Arista | 没有公开的盒内神经网络。AI Analyzer 在硬件上按 100 微秒采集 ECMP 成员利用率，结果可回馈动态负载均衡 | CLB、DLB、PFC 感知调度、CSIG、Fast CNP、MRC 等 EOS / 芯片特性 | CloudVision 上的 AVA、Ask AVA、CV UNO；SuperNIC 或服务器上的远端 EOS AI Agent |

## 华为

数据中心交换机 CloudEngine 9800、8800、6800、16800、XH16800 的 V300 文档给出了唯一一套可以在设备上加载模型并推理的实现。园区 CloudEngine S 配置指南里的 EAI 是 Egress ARP Inspection（基于 DHCP Snooping 的 ARP 定向转发），和嵌入式人工智能不是同一项功能。

### 本机：EAI 与 AI ECN

EAI 是设备内的公共框架，负责模型管理、数据采集、预处理，并把推理结果交给订阅它的业务。设备自带默认模型，不能卸载；最多再加载 20 个模型文件。新文件通过校验后，已启用的 AI 业务自动改用较新版本。CE16800 的相关命令限于 J、J2、P、SAN 系列板卡。

AI ECN 用在无损队列上，目标是按现网流量改 ECN 阈值，兼顾时延和吞吐。设备把队列长度等流量特征送给 AI ECN 组件，再由 EAI 给出阈值：

- 已知场景走模型推理，文档称为 NN 模式，使用预置神经网络。
- 未知场景走启发式推理，文档称为 BBR 模式，按现网状态持续修正阈值。
- 显示命令里还能看到 STATIC，表示静态阈值。

V300R025C10 配置指南中的模型包括集中式计算、分布式存储、分布式文件存储、高性能计算 `ai_ecn_hpc`、通用计算 `ai_ecn_gpc`。未指定模型时默认加载分布式存储模型。AI ECN 与静态 ECN 合计可用队列数有限制，AI ECN 本身也有队列数上限，以对应版本的注意事项为准。许可控制项是 `CE-LIC-AFRD`。

配置入口在 `ai-service` 下：`ai-ecn`、`assign queue`、`ai-ecn enable`。可用 `display ai-ecn calculated state` 查看计算出的低阈值、高阈值、标记概率、当前模式和生效模型。模型更新命令是 `load ai-service model-file`。

### 同视图下的智能算法，文档未描述为神经网络

这些功能经常和 AI ECN 一起放在 AI 业务视图或智能无损章节，许可上也常和 `CE-LIC-AFRD` 或 N1 Premium 包绑定。公开说明写的是规则或闭环控制，不是神经网络：

- iQCN：设备判断拥塞后主动向源网卡发 CNP，缩短只靠接收端 CNP 的反应时间。与 NPCC 互斥。
- NPCC：网络侧主动拥塞控制，可按高吞吐或低时延模式工作，分 IPv4 / IPv6。与 iQCN、动态负载均衡存在互斥。
- iNOF：面向无损 NVMe over Fabrics 的主机与网络协同。
- NSLB、Flow Matrix、Rail Group：按 AI 集群的轨道和流量矩阵做网络级负载分担。
- Dragonfly / Graceful Adaptive Routing：按拓扑和链路拥塞选择较短、未拥塞的路径。
- TCP FlexBuffer、rPFC、FLB、差分调度：缓冲、流控和调度优化。

N1 软件包把交换机功能、iMaster NCE-Fabric 和 FabricInsight 绑在一起卖。Foundation、Advanced、Premium 分别对应网络自动化、辅助驾驶和 L3 自动驾驶场景。流量分析、健康度、意图和数字地图在控制器或分析器上，不在交换机转发面上。

## Cisco

Cisco 把机器学习放在分析系统或控制器里。交换机负责导出特征、做应用识别，或者为盒内推理预留硬件。

### 本机能力

Encrypted Traffic Analytics 从 IOS XE Fuji 16.8.1a 进入 Catalyst 9300，后来扩展到部分 Catalyst 9400 引擎。交换机按流导出序列包长和时间（SPLT）以及初始数据包（IDP），规模说明约为每秒 2000 条流。IOS XE 配置指南写着 ETA “uses machine learning”，但部署指南和 Secure Network Analytics 白皮书把多层统计机器学习放在分析系统：交换机 ASIC 提供加密流元数据，恶意软件判断和加密合规分析在 Secure Network Analytics（原 Stealthwatch）完成。因此 ETA 的本机部分是特征提取，不是盒内模型推理。

AI Endpoint Analytics 的主要遥测来自 Catalyst 9000 上的 NBAR。NBAR 是交换机内的深度包检测，IOS XE 17.6 之后才能给这项分析供数。画像规则、智能分组和仿冒检测的机器学习在 Catalyst Center 及其连接的 Cisco 云上完成。

C9350-48HXG 的数据手册写明：8 核 CPU 加集成 GPU，“硬件已准备好支持较小 AI 工作负载的盒内推理”。同一份数据手册没有给出已经随 IOS XE 交付的命名模型或推理命令。C9350 系列另外支持在交换机 CPU 上托管容器，例如 ThousandEyes。那是应用托管能力，不是交换机自带的 AI 功能。

C9000 Smart Switch（C9350、C9550、C9610）的概览把“AI 驱动分析、异常检测”和 Silicon One、板载安全放在一起。能核对到的具体机制仍是 Flexible NetFlow、NBAR、流式遥测和应用托管。

### 控制器侧

Catalyst Center 3.1.x 内置 Cisco AI Assistant，用自然语言做监测、排障和文档检索，并和 Workflows 结合执行例行动作。AI Network Analytics 在本地或 Cisco 云上的分析引擎里学习每个网络的正常行为，用来减少误报、看异常和根因。这些引擎不在交换机上。

Nexus Dashboard Insights 对 N9000 遥测做基线、异常关联、预测和处置建议，也能看 RoCEv2 的 ECN / PFC 拥塞。Dashboard 4.3.1 把 AI 作业和 GPU、交换机接口、服务器网卡统计关联起来，并在 Dashboard 上提供 MCP 服务，用来连接 Cisco Cloud Control 或客户自己的大模型。大模型和异常引擎都在 Dashboard 或外部模型侧。N9000 在 AI 网络里承担的是遥测、缓冲和负载均衡，不是模型推理。

## HPE

HPE 网络现在同时包含 Aruba 与 Juniper。两边都把机器学习放在 Central 或 Mist，交换机侧最接近 AI 的是 AOS-CX 自带的分析引擎。

### 本机：Network Analytics Engine

NAE 做在 AOS-CX 里面，官方开发文档写明不需要额外许可证，也不需要另装软件。它读配置与状态数据库、时间序列数据库和 REST API，用代理监测指标、判断条件、发告警，并可以执行纠正动作。10.10 起提供 NAE-Lite，用 CLI 建代理，不必写 Python。

AOS-CX 10.14 NAE 指南覆盖 6200、6300、6400、8100、8320、8325、8360、8400、9300、10000。脚本数、代理数和时间序列保留天数按系列相差很大，接入交换机明显小于 8400 这一档。

10.1 引入的 Baseline 在交换机上学习被监测数据，再用高、低倍率形成动态阈值。10.14 指南给出的算法是 MaxAlgorithm：对平滑后的数据算一个基线，异常窗口内不把尖峰写回基线。这是本机统计自适应，不是神经网络。2018 年的会议演示曾把它称作 machine learning；现行指南只描述学习窗口、平滑和倍率。

NAE 能把配置变更和随后的状态变化关联起来，适合做根因的第一步。它不会自行生成跨网络的自然语言结论。

### 云侧，2026 年已经覆盖 CX 交换机

2026 年 5 月和 6 月的 HPE 公告把 Marvis 的自动驾驶动作带进 Aruba Central，有线口修复是其中一项；同时让 CX 接入交换机进入 Mist。Mist 侧给出的有线能力包括上线前后的 AI 可见性、零接触开通、二层接入保障、动态抓包、服务等级和建议动作。这些判断在 Mist 或 Central，不在 AOS-CX 进程里。

Juniper EX / QFX 归入 HPE Juniper Networking 之后，模式相同。Junos 里的 CloudX、Mist Cloud Daemon 和 Junos Mist Daemon 负责安全连接、周期统计、配置下发和按需抓包。服务等级、坏线缆、协商不匹配、VLAN 缺失、生成树环路等判断来自 Mist 的机器学习。EX4000 可以云原生开通，推理位置仍然是 Mist。QFX 进入 HPE AI Factory 后，由 Data Center Director 管理；公开公告强调的是 AI 集群组网和运维集成，没有给出交换机内的神经网络。

## Arista

EOS 在每台交换机上维护 SysDB，并把状态流式送到 CloudVision 的 NetDL。这个架构是后面所有分析的前提，本身不是模型。

### 本机：采集和 AI 以太网算法

7060XE7 数据手册把 AI Analyzer 定义为硬件能力：按最短 100 微秒汇总 ECMP 成员利用率，用来观察 AI 流量的短时爬升，并把结果用于动态负载均衡的均匀分担。2025 年 3 月的新闻稿同时说 Etherlink 上的 AI Analyzer 由 AVA 提供分析体验。可以同时成立的读法是：微秒级计数在交换机硬件里，跨作业的分析在 CloudVision。

EOS Smart AI 套件里、文档写成算法而不是模型的本机特性包括：

- Cluster Load Balancing：面向 RDMA 的集群负载均衡，减少长尾时延。2025 年 3 月先在 7260X3、7280R3、7500R3、7800R3 提供，并计划扩展到 7060X5、7060X6、7800R4。
- Dynamic Load Balancing，以及 PFC 感知的 DLB / ECN。
- Congestion Signaling、Fast CNP、增强 DCQCN、RoCEv2、报文喷射和报文裁剪。
- 7060XE7 上的 MRC 与链路层重传，用来避免单链路抖动把整个训练作业停住。
- EOS NetDL Streamer：把细粒度遥测持续送进 NetDL，替代只靠 SNMP 轮询。

远端 EOS AI Agent 由 AVA 驱动，运行位置是 SuperNIC 或服务器，用来把网卡和服务器遥测送进 NetDL。它不是交换机 ASIC 上的模型。

### CloudVision

AVA 消费 EOS 状态流，做时间序列异常、逐跳异常、事件关联和处置建议。CV UNO 把网络、系统和 AI 作业放进同一个 NetDL 视图，用来看作业完成、拥塞、缓冲和链路利用率。Ask AVA 是 CloudVision 里的自然语言入口，处于 beta；它按当前用户权限检索、画图，并可在设备上发起 ping、traceroute 或 EOS 命令。AGNI 是 CloudVision 上的身份服务，数据手册称为 AI-driven，服务于微分段，不在交换机转发进程中推理。

## 怎么理解这四家

截至 2026 年 10 月的公开文档，只有华为 CloudEngine 数据中心交换机明确支持在设备上加载模型文件，并用神经网络为无损队列计算 ECN 阈值，未知流量再退回启发式搜索。

HPE Aruba 是四家里另一家把自适应计算放进交换机操作系统的厂商，但是 NAE 基线是平滑和倍率，不是可更换的神经网络模型。

Cisco、Arista 和 HPE Juniper 的异常检测、根因和自然语言助手都在 Catalyst Center、Nexus Dashboard、Secure Network Analytics、CloudVision、Mist 或 Aruba Central。交换机贡献的是芯片级特征、微秒或毫秒级计数，以及状态流。

如果比较的是“交换机能不能承载 AI 训练网”，四家都有无损以太网、拥塞反馈和动态负载均衡。那是网络服务 AI 的能力，和交换机自己运行 AI 模型不是同一件事。

## 来源

- 华为 AI ECN 原理与配置（CloudEngine 9800/8800/6800 V300R025C10）：<https://support.huawei.com/enterprise/en/doc/EDOC1100561761/ff32f49a/understanding-ai-ecn>
- 华为 EAI 概述：<https://support.huawei.com/enterprise/en/doc/EDOC1100561779/5a320d4a/overview-of-eai>
- 华为 EAI 模型加载：<https://support.huawei.com/enterprise/en/doc/EDOC1100561761/3beb425f/optional-configuring-model-files-for-eai>
- 华为 CE16800 EAI 命令（J/J2/P/SAN 板卡）：<https://support.huawei.com/enterprise/en/doc/EDOC1100561849/89b899eb/eai-configuration-commands>
- 华为许可控制项（AI ECN / iQCN 为 CE-LIC-AFRD）：<https://support.huawei.com/enterprise/en/doc/EDOC1100295135/a0fb1667/overview-of-license-control-items>
- 华为 CloudFabric N1：<https://info.support.huawei.com/info-finder/encyclopedia/en/CloudFabric+N1+Business+Model.html>
- 华为园区 EAI（Egress ARP Inspection，不是嵌入式 AI）：<https://support.huawei.com/enterprise/en/doc/EDOC1100411524/1e477ce0/configuring-eai>
- Cisco ETA（Catalyst 9300，IOS XE 26.x）：<https://www.cisco.com/c/en/us/td/docs/switches/lan/catalyst9300/software/release/26-x/configuration_guide/nmgmt/b_26x_nmgmt_9300_cg/configuring_encrypted_traffic_analytics.html>
- Cisco ETA 非 Fabric 部署指南：<https://www.cisco.com/c/dam/en/us/td/docs/solutions/CVD/Campus/eta-nonfab-deploy-guide-2019oct.pdf>
- Cisco Secure Network Analytics 加密流量分析白皮书：<https://www.cisco.com/c/en/us/products/collateral/security/stealthwatch/white-paper-c11-740605.html>
- Cisco AI Endpoint Analytics（Catalyst Center 3.1）：<https://www.cisco.com/c/en/us/td/docs/cloud-systems-management/network-automation-and-management/catalyst-center/3-1-x/user_guide/b_cisco_catalyst_center_user_guide_3_1_x/endpoint-analytics-1-0.html>
- Cisco AI Assistant 方案说明：<https://www.cisco.com/c/en/us/solutions/collateral/artificial-intelligence/ai-assistant-so.html>
- Cisco C9350 数据手册（48HXG 板载 GPU）：<https://www.cisco.com/site/us/en/products/collateral/networking/switches/c9350-series-smart-switches/c9350-series-smart-switches-ds.html>
- Cisco Nexus Dashboard 4.3.1 AI 作业监测：<https://www.cisco.com/c/en/us/td/docs/dcn/nd/4x/articles-431/editing-fabric-settings-ai_ml-data-center-routed.html>
- HPE Aruba NAE 入门：<https://developer.arubanetworks.com/aoscx/docs/nae-getting-started>
- AOS-CX NAE 基线说明（Airheads）：<https://airheads.hpe.com/discussion/what-is-baselining-and-how-can-i-add-it-to-my-nae-script>
- HPE，2026-06，CX 进入 Mist、Marvis 进入 Central：<https://www.hpe.com/us/en/newsroom/press-release/2026/06/hpe-expands-self-driving-networks-across-edge-campus-data-center-and-ai-factories.html>
- Juniper EX4000 与 Mist：<https://www.juniper.net/documentation/us/en/hardware/ex4000/topics/concept/managing_ex4000_switches_using_juniper_mist.html>
- Arista，2025-03，CLB 与 CV UNO：<https://investors.arista.com/Communications/Press-Releases-and-Events/Press-Release-Detail/2025/Arista-Introduces-Intelligent-Innovations-for-AI-Networking/default.aspx>
- Arista 7060XE7 数据手册（AI Analyzer、DLB、CLB）：<https://www.arista.com/assets/data/pdf/Datasheets/7060XE7-Datasheet.pdf>
- Arista，2026-06，1.6T Smart AI 特性：<https://www.arista.com/en/company/news/press-release/24102-pr-20260609>
- Ask AVA：<https://www.arista.io/help/articles/overview-core-tools-ask-ava>
- CloudVision 数据手册（AVA、AGNI）：<https://www.arista.com/assets/data/pdf/Datasheets/EOSCloudVision_DataSheet.pdf>
