## Changes

**Rewarded**
- Wire rewarded ad feedback icon and report flow (#783)
- Notify MRAID viewable event for rewarded ads (#775)
- Align Nova Rewarded with MON Tech Design and Android demo parity (#768)
- Add Nova Rewarded Ad support with `AD_EVENT_REWARDED` MES event (#721)

**HTML / MRAID**
- Fix MRAID playable creative failing to play (#764)
- Support MRAID viewable change (#739)
- Inject MRAID directly into ad HTML view (#736)
- Block navigation initiated from iframe (#737)
- Allow HTML ad input resource (#731)

**MES / Reporting**
- Forward H5 `product_id` / `grid_idx` to DSP click reporting (#754)
- Support in-SDK ad bid-lost reporting (#750)
- Add `ad_dismiss` MES event (#744)

**Misc**
- Multiply AppLovin ad price by 1000 to align with CPM (#743)
- Add `@_implementationOnly` to SwiftProtobuf imports to prevent swiftinterface leak (#762)
- Move `AppLovinMediationGoogleAdapter` from `MSPApplovinMaxAdapter` to DemoApp (#742)
