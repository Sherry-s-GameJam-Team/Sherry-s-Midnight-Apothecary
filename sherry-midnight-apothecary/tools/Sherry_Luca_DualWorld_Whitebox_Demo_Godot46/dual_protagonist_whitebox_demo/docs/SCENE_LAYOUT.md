# 场景搭建约定

正式关卡建议把白盒 Demo 的运行时生成方式改成编辑器可见的节点实例，但保持以下边界：

```text
SharedWorld               永远显示/永远碰撞
CorruptedWorld            Sherry 激活
OriginalWorld             Luca 激活
Actors                    两个角色常驻
Systems                   世界状态、主角控制、机关共享状态
```

## 对齐

两个世界根节点永远 `(0,0)`、`scale=(1,1)`。不要通过移动整个 `CorruptedWorld` 或 `OriginalWorld` 来修图。

相同位置但不同外观的素材：两个 Sprite 使用完全一致的位置/pivot。

不同地形轮廓：各自配置 CollisionShape2D 或 CollisionPolygon2D。

## 白盒资源替换

`assets/` 中图片只用于 Demo。正式制作时可逐个替换 PNG，只要保持对应 Sprite 的逻辑位置；若图片画布尺寸变化，重新核对 pivot/scale，而不要移动世界根节点。
