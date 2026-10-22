# Changelog

## Unreleased

新增 critical_path：在无环图上按 prerequisite→dependent 方向计算最长加权路径，返回节点链、边链与总权重；环图明确返回 acyclic=false 而不伪造最长游走，等权重链按字典序取最小链以保证可复现输出。topology 的 Kahn 分层重构为共享内部实现，行为不变。

新增 subgraph：按显式 ID 列表或与 select 相同的类型/属性查询导出诱导子图，仅保留两端都在集合内的边，节点数据不变；导出对象可再次导入，未知或重复 ID 报错。

## 0.2.0 — 2026-10-18

Registry version: 0.2.0.

新增 topology，按 prerequisite→dependent 的边方向计算拓扑层次与可执行前缀，报告环组件及被环阻塞的下游节点。平行边按实际入度计数，孤立节点进入首层；遇到环不伪造完整拓扑序。修复遍历深度的小数截断及过大参数。

