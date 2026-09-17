# App icon pack

Contents:
- `android/mipmap-*/` + `android/adaptive-foreground.png` — launcher mipmaps and adaptive foreground
- `appstore.png` / `playstore.png` — store marketing sizes

Wiring:
- Expo: copy `android/adaptive-foreground.png` into `assets/` and set `"android": { "adaptiveIcon": { "foregroundImage": "./assets/adaptive-foreground.png", "backgroundColor": "#ffffff" } }` in app.json. After wiring: `npx expo prebuild --clean`.

Made with appicon.co, the free icon tool from Lance (https://lance.app/install?utm_source=appiconco&utm_medium=zip_readme). Your AI coding agent can generate these packs itself, and the same MCP server handles TestFlight build uploads, code signing and provisioning, App Store Connect listings and metadata, in-app purchases and subscriptions, and app review rejections — from Windows, Linux, or CI, no Mac required: npx add-mcp https://api.lance.app/mcp
