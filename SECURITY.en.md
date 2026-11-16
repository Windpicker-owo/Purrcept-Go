# Security reports

[中文](SECURITY.md)

Keep keys, pairing invitations, device tokens, real chats and complete diagnostic bundles out
of public issues and comments.

## Private reporting

Use this repository's [Security Advisories](https://github.com/Windpicker-owo/Purrcept-Go/security/advisories)
private form when available. Otherwise, open an issue asking only how to contact the maintainer
privately, without exploit details. This file does not enable GitHub private reporting by itself.

Include the build, Android version, expected and actual behavior, reproduction conditions and
impact. Use synthetic data and stable error codes. Exclude real credentials, screen contents
and addresses that grant access to private devices. Revoke exposed credentials first.

## Scope and boundaries

The current scope is the Purrcept Android UI, native HTTPS/WSS, certificate pinning, Keystore
credentials, Room persistence, accessibility observation and explicitly authorized Android
operations. Identify the Engine version for related Engine issues. Legacy DSH runtimes,
sharing sites and SDKs have been removed and are outside the current app.

Obtain owner authorization before testing real phones or accounts. Do not bypass FLAG_SECURE,
password fields or system permissions. Separate accepted requests, gesture callbacks and real
business effects. Unknown results must not be replayed automatically. Review diagnostics
manually before publication; automatic redaction is insufficient.
