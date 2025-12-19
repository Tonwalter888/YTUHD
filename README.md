# YTUHD

Unlocks 1440p (2K) and 2160p (4K) resolutions in iOS YouTube app.
This requried at least iOS 11 and recommend at least A12 chip for the best 2K and 4K experience.

## Known issues
- Some videos may not playable in SW VP9.
- And some videos may not get 4K in SW AV1.

## Backstory
- The reason I created this repo because the latest version of YTUHD have some problems with libundirect that can't unlock 4K if you're sideloading.
- And in main YTUHD repo,PoomSmart try to make 2K and 4K work in older devices (older than A12 chip) but libundirect doesn't work with sideloading. (maybe)
- If anyone can make libundirect works in sideloading,PLEASE open a new issue and explain how you did it.
- I removed auto reload logic,fixed All VP9 not working,fixed settings crashes and updated some codes from PoomSmart so now 2K and 4K videos should playing fine.
- Maybe this repo might help you! If you find any bugs,you can open a new issue or make a PR to here.
