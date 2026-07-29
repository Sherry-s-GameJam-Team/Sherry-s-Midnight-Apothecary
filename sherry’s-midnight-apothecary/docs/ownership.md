# 三人代码所有权

## 白天玩法负责人

```text
day/player/
day/camera/
day/combat/
day/harvesting/
day/puzzles/
day/portals/
day/levels/
```

## 夜间玩法负责人

```text
night/alchemy/
night/customers/
night/shop/
night/economy/
night/ui/
```

## 整合与资源负责人

```text
app/
shared/
day/day_runtime.*
night/night_runtime.*
art/
audio/
tests/
docs/
```

`PlayerData`、昼夜结果、`GameFlow` 和 `project.godot` 属于共享接口，修改时通过 Pull Request 审核。

