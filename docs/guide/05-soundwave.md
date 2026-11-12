# 5. Get ready for Soundwave

## Why

[Soundwave](https://github.com/albatrossflavour/soundwave) reads Vuls's last complete run and pushes the findings into Puppet Enterprise Vulnerability Remediation. Its vuls cassette reads the files on this node, so Soundwave goes on the Vuls scanner.

## Before you start

- Step 4 done, with `last-complete-run` naming a finished run

## Do it

Nothing to do here. Soundwave's defaults already point at this module's paths.

## Done when

`sudo cat /var/lib/vuls/last-complete-run` names a run, as in step 4. Soundwave only reads the run named there, never a newer directory that may still be being written.

## If it fails

Soundwave logs `vuls cassette: no complete Vuls run recorded in /var/lib/vuls/last-complete-run` when there's nothing for it to read. Go back to step 4.

## Next

Continue with [the Soundwave install guide](https://github.com/albatrossflavour/soundwave/blob/main/docs/guide/README.md), and turn on its vuls cassette there.
