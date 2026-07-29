# 三人代码所有权

## 炼药负责人

```text
features/alchemy/
features/customers/
features/shop/
features/economy/
content/definitions/ingredients/
content/definitions/potions/
content/definitions/recipes/
content/definitions/customers/
```

## 室外场景负责人

```text
art/environments/
content/levels/*/visual/
环境动画
环境特效
污染与净化版本
```

## 关卡与整合负责人

```text
app/
core/
features/exploration/
features/player/
features/camera/
features/combat/
features/harvesting/
features/puzzles/
features/portals/
content/levels/*/gameplay/
tests/
```

共享文件（包括 `project.godot`、README、跨领域定义和公共契约）必须通过 Pull Request 审核。尽量不要让两名成员同时编辑同一个 `.tscn`；视觉与玩法分别放入 `visual/` 和 `gameplay/` 后由运行时组合。

