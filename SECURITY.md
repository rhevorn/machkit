# Security Policy

MachKit reads system metadata and can remove files selected by the user, so
security reports are treated as high priority.

Please use GitHub's private vulnerability reporting for issues involving path
validation, privilege boundaries, WebView bridges, command execution, or the
exposure of local data. Do not publish exploit details in a public issue before
a fix is available.

Include the affected MachKit version, macOS version, reproduction steps, and the
smallest proof of concept that demonstrates the boundary failure. Reports about
unsupported or modified builds should also identify the commit used.

Security fixes are applied to the latest release line. There is currently no
separate long-term-support branch.
