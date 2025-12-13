# [1.2.0](https://github.com/Flo-R1der/paperless-nextcloud-sync/releases/tag/1.2.0)

## Added
- Cronjob capabilities (#17)
    - Log-Files older 90 days will be cleaned up automatically  
    - full sync can be triggered by adjusting the [cronjob-file](cronjob)  
  > see "🧩 Advanced Functionalities" in the readme for adjustments
      

## Improvements
- TimeZone Variable `$TZ` is now considered (#19)
- Health-Check now also observes if `cron` is running
- Some small errors are fixed
- Logging is now providing more detailed information

## Documentation updates
- Optional settings are now collapsed in README.md
- How to adjust the Log-File retention
- Add "Advanced Functionalities"-Section to set up custom cron jobs


<br>

---
# [1.1.0](https://github.com/Flo-R1der/paperless-nextcloud-sync/releases/tag/1.1.0)

## Added
- special characters for url/username/password supported
- support for ownCloud (tested version 10.15)
- support for OpenCloud (tested version 2.3)


## Improvements
- better verbosity and logging
- externalize `sync_live.sh` as separate script

## Documentation updates
- supported cloud-systems with tested version


<br>

---
# [1.0.1](https://github.com/Flo-R1der/paperless-nextcloud-sync/releases/tag/1.0.1)

## Improvements
- some improvements from the [abobot fork](https://github.com/abobot/paperless-nextcloud-sync)
- sync script made more robust to work also on empty instances
- logging improved

## Documentation updates
- formatting for better understanding
- comparison to other solutions

<br>

---
# [v1.0.0](https://github.com/Flo-R1der/paperless-nextcloud-sync/releases/tag/v1.0.0)

## Added
- publish image to [ghcr.io](https://github.com/users/Flo-R1der/packages/container/package/paperless-nextcloud-sync) and [hub.docker.com](https://hub.docker.com/r/flor1der/paperless-nextcloud-sync) (#9)
- container exit-code 0

## Improvements
- made the sync script more robust

## Documentation updates
- formatting with Info-blocks
- Links to [ghcr.io](https://github.com/users/Flo-R1der/packages/container/package/paperless-nextcloud-sync) and [hub.docker.com](https://hub.docker.com/r/flor1der/paperless-nextcloud-sync)


<br>

---
# [v0.9.0](https://github.com/Flo-R1der/paperless-nextcloud-sync/releases/tag/v0.9.0)
**first release / pre-release**  
Current version, used on my system. Changes for first production-release coming up on the [dev-branch](../../tree/dev)!
