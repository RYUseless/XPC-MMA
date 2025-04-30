# XPC-MMA
## PracticalClass/
- Some big epic class stuff we had to do.
- will add tree later → now project is priority numero uno.


## MPC-MMA project → "TotallyLegitCalculator"
> in /project folder
- Chatting application hidden behind innocent calculator
- TLS 1.3, AES-CBC encryption, derivate cipher for aes key commingsoonTM
- supported on linux for now
- android support will be recovered later on

- in backend/scripts are scripts for compaling implemented scr codes → execute vith ``source <path or whatever/>_compile_apps.sh``
- compiled apps should be in backend/dist/* -- api for peer_ssl, api for config and app_console, which is console standalone of peer ssl connection → simply run vith ``./app_console``

- There are for now plenty of untinkered spots -- will continue primarily on backend -- derivate cipher and schnorr algorithm
- !!! I cast "works on my machine" -- there are plenty of issues with the C backend for flutter and linux scaling, so as it is for now, i am unable to make it more unversal

### How to install:
- clone this repo
- compile the backend apps as shown up  ``source <path to scripts/ folder, or if you are inside, dont do this at all>_compile_apps.sh``
- go to dist and run **app_console** for cli peer to peer connection (only inside of one network, or if you have fowarding etc implemented -- than it works out too)
- for flutter, it is recomended to open vs code, and run it from there -- there may be some issues, there may be not, i did some testing on my two PCs -- but not sure if it is even able to do something.

**STILL IN DEVELOPMENT -- NOW IN STAGE FOR XPC-MMA PROJECT, AFTER THAT, I WILL BASICALLY REDO THIS FROM THE GROUND -- some new security things i would like to try etc.**
