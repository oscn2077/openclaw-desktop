# App Icons

electron-builder 需要以下图标文件才能正确打包：

## 必需文件

| 文件 | 平台 | 规格 |
|------|------|------|
| `icon.ico` | Windows | 256×256, 多尺寸 ICO (含 16/32/48/64/128/256) |
| `icon.icns` | macOS | 1024×1024, Apple ICNS 格式 |
| `icon.png` | Linux | 512×512 或 1024×1024, PNG 格式 |

## 生成方法

### 方法 1：从 PNG 生成全部格式

准备一个 1024×1024 的 PNG 源文件，然后：

```bash
# macOS (需要 iconutil)
mkdir icon.iconset
sips -z 16 16 icon-source.png --out icon.iconset/icon_16x16.png
sips -z 32 32 icon-source.png --out icon.iconset/icon_16x16@2x.png
sips -z 32 32 icon-source.png --out icon.iconset/icon_32x32.png
sips -z 64 64 icon-source.png --out icon.iconset/icon_32x32@2x.png
sips -z 128 128 icon-source.png --out icon.iconset/icon_128x128.png
sips -z 256 256 icon-source.png --out icon.iconset/icon_128x128@2x.png
sips -z 256 256 icon-source.png --out icon.iconset/icon_256x256.png
sips -z 512 512 icon-source.png --out icon.iconset/icon_256x256@2x.png
sips -z 512 512 icon-source.png --out icon.iconset/icon_512x512.png
sips -z 1024 1024 icon-source.png --out icon.iconset/icon_512x512@2x.png
iconutil -c icns icon.iconset -o icon.icns

# Windows ICO (需要 ImageMagick)
convert icon-source.png -define icon:auto-resize=256,128,64,48,32,16 icon.ico

# Linux — 直接用 512x512 PNG
cp icon-source.png icon.png
```

### 方法 2：使用 electron-icon-builder

```bash
npm install -g electron-icon-builder
electron-icon-builder --input=icon-source.png --output=./
```

### 方法 3：在线工具

- https://www.electron.build/icons
- https://icoconvert.com/

## 当前状态

`icon.png` 是一个 256×256 的占位符图标（🦞 OpenClaw logo placeholder）。
正式发布前请替换为设计好的品牌图标。
