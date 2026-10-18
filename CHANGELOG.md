# Changelog

## 0.2.0 — 2026-10-18

Registry version: 0.2.0.

新增 topology，按 prerequisite→dependent 的边方向计算拓扑层次与可执行前缀，报告环组件及被环阻塞的下游节点。平行边按实际入度计数，孤立节点进入首层；遇到环不伪造完整拓扑序。修复遍历深度的小数截断及过大参数。

