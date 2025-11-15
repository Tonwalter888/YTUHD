# YTUHD

Unlocks 1440p (2K) and 2160p (4K) resolutions in iOS YouTube app.
This requried at least iOS 14 and recommend at least A12 chip for the best 2K and 4K experience.

## Known issue
Sometimes the video will stuck at loading so I'm finding a solution for this.

- The reason I created this repo because the latest version of YTUHD required libundirect and there are some problems with Cydiasubstrate.framework that doesn't work with YTUHD.
- And in main YTUHD repo,PoomSmart try to make 2K and 4K work in older devices (older than A12 chip) but some logic don't work with Sideloading.
- Plus my main point is to make 2K and 4K work in A12 chip and newer,so I created this repo to solve this.
- I removed auto reload logic,fixed All VP9 not working and updated some A/B settings and codes from PoomSmart so now 2K and 4K videos should playing fine.
- Maybe this repo might help you! If you find any bugs,you can open a new issue or make a PR to here.
