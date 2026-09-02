# 反馈：Zepp 同步到 Apple 健康的训练记录，距离数据无法被健康 App 汇总统计到

## 问题现象

用 Zepp App 记录一次训练（骑行/跑步/步行等）并同步到 Apple 健康 App 后：

- 打开这条训练记录的详情页，能正常看到距离数据（比如"15.2 公里"）
- 但健康 App 首页的"骑行里程""步行+跑步距离"等**距离汇总卡片**，以及其他依赖这类汇总数据的第三方 App（比如根据距离类型数据做统计的健康分析工具），**完全看不到这部分距离**，汇总数值不会因为这次训练而增加

也就是说：训练详情里有距离，但健康 App 的距离统计体系里没有。

## 复现步骤

1. 用 Zepp 完成一次带 GPS/距离的训练（比如骑行），同步进 Apple 健康
2. 打开 Apple 健康 App，进入这条训练的详情页 —— 能看到正确的距离
3. 回到健康 App 首页，查看"骑行里程"这类汇总卡片对应时间段的数值 —— 没有反映刚才这次训练的距离
4. 用代码直接查询 HealthKit 中 `distanceCycling`（或对应运动类型的距离类型）在这次训练时间区间内的独立数据点 —— 查不到任何记录

## 技术原因分析

HealthKit 里，一条训练记录（`HKWorkout`）本身携带的距离信息，和"独立的距离数据点"（`HKQuantitySample`，类型如 `HKQuantityTypeIdentifier.distanceCycling`）是两套不同的东西：

- 健康 App 首页的距离汇总卡片、以及大多数第三方 App 做距离统计时，查询的是**独立的距离数据点**（按类型 + 时间区间聚合求和）
- 而 `HKWorkout` 详情页展示的距离，可能来自这条训练自身携带的聚合属性（尤其是通过较旧的初始化接口 `HKWorkout(activityType:start:end:workoutEvents:totalEnergyBurned:totalDistance:device:metadata:)` 写入时，`totalDistance` 只是这个训练对象自身的属性，并不是一条独立、可被单独查询到的 `HKQuantitySample`）

我们用代码复现验证过：如果训练是用上述旧式初始化接口写入的（只设置 `totalDistance` 参数，不额外写入独立的 `distanceCycling` 类型数据），确实会出现"详情页有距离、汇总查询不到"这个现象，跟观察到的 Zepp 同步行为完全吻合。据此推测 Zepp 目前向 HealthKit 写入训练数据时，使用的可能正是这条旧式接口，或者虽然用了新接口（`HKWorkoutBuilder`）但没有额外调用 `addSamples(_:)` 把距离作为独立样本关联写入。

## 影响范围

- 苹果自己的健康 App 首页/趋势里的距离汇总不准确
- 任何依赖 HealthKit 距离类型数据做统计的第三方 App（运动分析、年度总结类工具等）都拿不到 Zepp 记录的训练距离
- 用户如果同时使用多个运动 App，会发现"总里程"对不上，需要自己排查才能发现是 Zepp 同步没有写完整

## 建议修复方式

改用 `HKWorkoutBuilder` 写入训练时，除了训练本身，额外把距离构造成独立的 `HKQuantitySample` 一并关联写入，示意代码：

```swift
let distanceSample = HKQuantitySample(
    type: HKQuantityType(.distanceCycling),   // 按运动类型对应的距离类型
    quantity: HKQuantity(unit: .meter(), doubleValue: totalDistanceMeters),
    start: workoutStartDate,
    end: workoutEndDate
)

builder.add([distanceSample]) { success, error in
    // ...
}
```

如果目前仍在使用旧式 `HKWorkout(activityType:...totalDistance:...)` 初始化接口，建议迁移到 `HKWorkoutBuilder`，这也是苹果目前推荐的写入方式（旧接口在近几个 iOS 版本中已被标记为 deprecated）。

## 短版本（适合字数受限的反馈表单）

现象：用 Zepp 记录一次骑行/跑步等训练同步到 Apple 健康后，打开训练详情能看到距离，但健康 App 首页"骑行里程"等距离汇总卡片、以及其他读取距离数据的 App，都统计不到这部分距离。直接查询该运动类型对应的距离数据（如 distanceCycling）在这次训练的时间区间内，查不到任何独立记录。

推测原因：Zepp 写入训练时，可能用的是旧式 `HKWorkout(activityType:...totalDistance:...)` 初始化接口，距离只作为训练对象自身的属性写入，没有作为独立的 `HKQuantitySample` 关联写入；也可能是用了新的 `HKWorkoutBuilder`，但没调用 `addSamples(_:)` 把距离样本一并写入。这两种情况都会导致距离只在训练详情页可见，无法被健康 App 的距离汇总统计到。

建议：改用 `HKWorkoutBuilder` 写入训练时，额外用 `addSamples(_:)` 把距离（对应运动类型的 `HKQuantityType`，如 `distanceCycling`/`distanceWalkingRunning`）作为独立的 `HKQuantitySample` 一并关联写入。

## 环境信息

- 发现问题的方式：对比训练详情页与健康 App 首页汇总数据，并通过代码直接查询 HealthKit 数据验证
- 涉及运动类型：骑行（其他有距离语义的运动类型，如跑步、步行、游泳等，预计存在同样问题）
