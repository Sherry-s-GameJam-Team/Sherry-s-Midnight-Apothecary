# AI 项目协作提醒

## 场景镜头

- `town`、`lake` 与 `raintree` 的镜头逻辑统一复用
  `game/main/scenes/town/town_camera_controller.gd` 中的
  `TownCameraController`。
- 室外镜头应平滑跟随角色；角色攀爬或进入高处时，镜头应沿纵向跟随。
- 进入室内时，镜头应平滑聚焦场景配置的室内中心点；离开室内后恢复室外跟随。
- 场景切换和预览由 `doorchanger` / `game_root` 协调时，应保留上述镜头模式，
  避免在场景脚本中另写一套 Camera2D 跟随逻辑。
- 各场景的镜头构图差异应优先通过 Marker2D、边界和控制器导出参数配置，
  不要修改共享控制器来硬编码单个场景的坐标。
- 这些内容仅供 AI 和开发协作参考，不应以提示框、提醒文字或其他 UI 显示在游戏中。
