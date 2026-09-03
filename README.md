# 里程补全 · Distance Backfill

[![CI](https://github.com/googollee/distance_backfill/actions/workflows/ci.yml/badge.svg)](https://github.com/googollee/distance_backfill/actions/workflows/ci.yml)

用 Zepp（Amazfit）、佳明 Garmin Connect 等第三方运动 App 记录的训练同步到 Apple 健康后，训练详情里能看到距离，但健康 App 首页"骑行里程""步行+跑步距离"等汇总卡片，以及其他依赖距离数据统计的 App，却看不到这部分里程——因为这些第三方 App 通常只把距离写进了训练记录本身，没有额外写入健康 App 用来做汇总统计的独立距离数据。

"里程补全"就是为解决这个落差而生：扫描健康 App 中的训练记录，把训练自带的距离统计补写为一条独立的距离数据，使健康 App 的汇总卡片和其他依赖距离数据的 App 都能正确统计到。

详细背景与设计见 [`docs/PRD-001.md`](docs/PRD-001.md)、[`docs/ADR-001.md`](docs/ADR-001.md) 及后续 ADR。

## 主要功能

- 一键扫描历史：一次性找出并补全所有有距离统计但尚未汇总的历史训练
- 后台自动补全（可选，默认关闭）：新训练同步进健康 App 后自动补全，无需打开本 App
- 覆盖骑行、跑步、步行、远足、游泳、划船、桨类运动、滑冰类、越野滑雪、高山滑雪、轮椅相关项目等一切具备距离语义的运动
- 绝不覆盖、绝不重复：只在训练确有距离统计、且对应独立距离数据尚不存在时才补写
- 可追溯、可撤销：本地留存所有写入记录，支持单条或批量撤销
- 过期提示：源训练记录被更新或删除后，对应记录会标记为"可能已过期"

## 开发

依赖：Xcode（iOS 18 SDK）、[XcodeGen](https://github.com/yonaskolb/XcodeGen)（`brew install xcodegen`）。

```sh
make generate  # 用 project.yml 生成 DistanceBackfill.xcodeproj
make test      # 生成工程并运行单元测试
make build     # 生成工程并构建 App
make release   # 归档并上传到 App Store Connect（需要 appstoreconnect/config.mk 中的签名凭证）
make clean     # 清理构建产物与生成的工程文件
```

`DistanceBackfill.xcodeproj`、`Generated/`、`build/` 均由 `xcodegen` 生成，不纳入版本控制，以 `project.yml` 为准。

## License

[BSD 3-Clause](LICENSE)
