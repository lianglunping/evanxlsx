# evanxlsx 0.3.1 candidate

Runtime acceptance pending. The baseline numeric review is run 36720911770 on unchanged 0.3.0.
It reproduced extreme finite-data mean/SD overflow and SD underflow, with normal controls retained.
本版修正均值/SD的中间运算缩放，并新增完整工作流。未改变既有导出实现和公开API。
验收通过前不更新main；旧版本通过结论不自动继承。
