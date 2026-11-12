# Installing Vuls

This guide takes you from an empty node to Vuls scanning every node in PuppetDB, and optionally on to the findings showing up in Puppet Enterprise.

The steps link to [the module's reference pages](../../README.md#reference) for each setting's detail.

## Which steps you need

Vuls works on its own, and nothing here needs Puppet Enterprise until step 5. Unlike Greenbone, Vuls can't scan a Linux node without logging in, so step 3 isn't optional.

| You want | Steps |
|---|---|
| Vuls scanning Linux and Windows nodes | 1 to 4 |
| The findings in PE Vulnerability Remediation | All five, then the Soundwave guide |
| Vuls beside Greenbone on the same node | All of them, and see [Keeping out of another scanner's way](../configuration.md#keeping-out-of-another-scanners-way) in step 4 |

## The steps

1. [Plan the scanner](01-plan.md)
2. [Install Vuls](02-install.md)
3. [Add scan credentials](03-credentials.md)
4. [Run a scan](04-scan.md)
5. [Get ready for Soundwave](05-soundwave.md)

## Upgrading

The module pins the Vuls release it installs, so a new Vuls arrives with a module upgrade. That's a Puppetfile change like any other, and needs no step of its own.
