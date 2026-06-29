# Phone LAN Remote Rehearsal

This document is the canonical hardware rehearsal gate for the phone LAN
remote-control stream.

No production code changes belong in this closeout slice. No release or tag is allowed from this document alone.

Use PASS, FAIL, BLOCKED, or NOT RUN only. Do not paste per-run dated evidence into this canonical matrix.

## Hardware Matrix

Automated tests are not hardware evidence. A row may become PASS only after
direct operator observation on the named device, network, or output path.

| Scenario | Result |
| --- | --- |
| Dedicated 5GHz router, iPhone Safari connects by QR | NOT RUN |
| Android Chrome connects by QR | NOT RUN |
| Public Wi-Fi with AP isolation fails gracefully | NOT RUN |
| Mac hotspot works | NOT RUN |
| Remote disabled rejects commands | NOT RUN |
| Token rotation invalidates old phone page | NOT RUN |
| Take Next latency acceptable | NOT RUN |
| Media play/pause works | NOT RUN |
| BGM play/pause/prev/next works | NOT RUN |
| Speaker mode works | NOT RUN |
| FTB long-press works, external output black | NOT RUN |
| Panic long-press works, external output black | NOT RUN |
| No accidental single-tap dangerous action | NOT RUN |
| Phone disconnect/reconnect safe | NOT RUN |
| Mac sleep/network change safe | NOT RUN |
| 60-minute soak with phone connected | NOT RUN |

## Security And Network Limits

The phone remote is LAN-only: no cloud relay, no public internet remote, and no UPnP or port mapping.

The token must not appear in logs. Support reports must not include token, full phone IP, program title, BGM title, or customer content.

Dangerous actions require long-press plus server confirmation nonce.

## Release Gate

This document does not approve a release by itself. Do not publish v0.6.0 until every required rehearsal row has real PASS evidence.
