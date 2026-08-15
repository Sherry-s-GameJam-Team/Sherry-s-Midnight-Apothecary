阿尔维斯母树树心门开启动画素材包
================================

内容
- frames/: 24 张透明 PNG 精灵帧
- forest_arvis_gate_open_sheet_6x4.png: 6列×4行透明精灵表
- forest_arvis_gate_closed_static.png: 第一帧，关闭静态状态
- forest_arvis_gate_open_static.png: 最后一帧，开启静态状态
- audio/forest_arvis_gate_open_sfx_sync.ogg: 推荐 Godot 使用的同步音效
- audio/forest_arvis_gate_open_sfx_sync.wav: 无损音效版本
- preview/preview_contact_sheet.jpg: 帧序列预览

动画参数
- 源视频：1470 × 630
- 时长：约 4.0167 秒
- 输出帧数：24
- 播放帧率：6 FPS
- 每帧画布：1470 × 630 RGBA
- 所有帧保持相同尺寸与锚点，没有裁切，避免门体在播放时跳动
- 精灵表：8820 × 2520，hframes=6，vframes=4
- 动画循环：false

Godot 推荐用法
1. 使用 AnimatedSprite2D。
2. 新建 SpriteFrames 动画 open。
3. 按 0001 -> 0024 顺序导入 frames/ 中的 PNG。
4. Animation Speed 设置为 6 FPS，Loop 关闭。
5. AudioStreamPlayer2D 使用 audio/forest_arvis_gate_open_sfx_sync.ogg。
6. 开启动画时同时播放音效。
7. 动画结束后切换到 forest_arvis_gate_open_static.png，或保持最后一帧。

若使用精灵表
- hframes = 6
- vframes = 4
- 帧索引 0-23，按从左到右、从上到下排列

抠图说明
- 原视频背景为接近纯白色。
- 透明处理只移除了“与画面边界连通的近白背景”，没有全局删除白色，因此石门、水光和高光中的浅色细节被尽量保留。
- 边缘做了窄范围羽化，以减少白色锯齿边。

命名建议
res://art/environments/forest/arvis_tree/animations/gate_open/
