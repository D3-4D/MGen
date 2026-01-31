# Maze Generator
```
      ▄▄▄▄▄▄▄▄▄▄▄   ▄▄▄▄▄▄▄▄▄   ▄▄▄▄▄▄▄▄▄▄▄  ▄▄▄▄▄▄▄▄▄▄▄  ▄         ▄  ▄▄▄▄▄▄▄▄▄▄  ▄▄▄▄▄▄▄▄▄▄▄  ▄▄▄▄▄▄▄▄▄▄▄  ▄▄▄▄▄▄▄▄▄▄▄ 
     ▐░░░░░░░░░░░▌ ▐░░░░░░░░░▌ ▐░░░░░░░░░░░▌▐░░░░░░░░░░░▌▐░▌       ▐░▌▐░░░░░░░░░░▌▐░░░░░░░░░░░▌▐░░░░░░░░░░░▌▐░░░░░░░░░░░▌
     ▐░█▀▀▀▀▀▀▀▀▀ ▐░█░█▀▀▀▀▀█░▌▐░█▀▀▀▀▀▀▀▀▀  ▀▀▀▀█░█▀▀▀▀ ▐░▌       ▐░▌▐░█▀▀▀▀▀▀▀█░▌▀▀▀▀█░█▀▀▀▀ ▐░█▀▀▀▀▀▀▀█░▌▐░█▀▀▀▀▀▀▀▀▀ 
     ▐░▌          ▐░▌▐░▌    ▐░▌▐░▌               ▐░▌     ▐░▌       ▐░▌▐░▌       ▐░▌    ▐░▌     ▐░▌       ▐░▌▐░▌          
     ▐░█▄▄▄▄▄▄▄▄▄ ▐░▌ ▐░▌   ▐░▌▐░█▄▄▄▄▄▄▄▄▄      ▐░▌     ▐░▌       ▐░▌▐░▌       ▐░▌    ▐░▌     ▐░▌       ▐░▌▐░█▄▄▄▄▄▄▄▄▄ 
     ▐░░░░░░░░░░░▌▐░▌  ▐░▌  ▐░▌▐░░░░░░░░░░░▌     ▐░▌     ▐░▌       ▐░▌▐░▌       ▐░▌    ▐░▌     ▐░▌       ▐░▌▐░░░░░░░░░░░▌
      ▀▀▀▀▀▀▀▀▀█░▌▐░▌   ▐░▌ ▐░▌ ▀▀▀▀▀▀▀▀▀█░▌     ▐░▌     ▐░▌       ▐░▌▐░▌       ▐░▌    ▐░▌     ▐░▌       ▐░▌ ▀▀▀▀▀▀▀▀▀█░▌
               ▐░▌▐░▌    ▐░▌▐░▌          ▐░▌     ▐░▌     ▐░▌       ▐░▌▐░▌       ▐░▌    ▐░▌     ▐░▌       ▐░▌          ▐░▌
      ▄▄▄▄▄▄▄▄▄█░▌▐░█▄▄▄▄▄█░█░▌ ▄▄▄▄▄▄▄▄▄█░▌     ▐░▌     ▐░█▄▄▄▄▄▄▄█░▌▐░█▄▄▄▄▄▄▄█░▌▄▄▄▄█░█▄▄▄▄ ▐░█▄▄▄▄▄▄▄█░▌ ▄▄▄▄▄▄▄▄▄█░▌
     ▐░░░░░░░░░░░▌ ▐░░░░░░░░░▌ ▐░░░░░░░░░░░▌     ▐░▌     ▐░░░░░░░░░░░▌▐░░░░░░░░░░▌▐░░░░░░░░░░░▌▐░░░░░░░░░░░▌▐░░░░░░░░░░░▌
      ▀▀▀▀▀▀▀▀▀▀▀   ▀▀▀▀▀▀▀▀▀   ▀▀▀▀▀▀▀▀▀▀▀       ▀       ▀▀▀▀▀▀▀▀▀▀▀  ▀▀▀▀▀▀▀▀▀▀  ▀▀▀▀▀▀▀▀▀▀▀  ▀▀▀▀▀▀▀▀▀▀▀  ▀▀▀▀▀▀▀▀▀▀▀ 
    
    ☆ S0Studios 2025 © ☆

    - Service: Recursive maze generation module
    - Release: 12/16/2025
    - Maintainer: @Dead_S0S / D3-4D
    - Version: 4 ( 7% Faster than previous version! )
```
## Overview

![](https://github.com/D3-4D/MGen/blob/main/Demo/Edit.gif)

This project consists of a recursive procedural maze generation library with multi-threading support written in Luau, optimized for the Roblox framework.

## Features

- OOP formatted
- Custom-designed algorithm
- Memory-based instant backtracking
- Post-regeneration path retention support
- Configurable operational ranges
- Custom recursion behavior (linear or randomized)
- Adjustable generation structuring through path preference settings

- Multi-threaded generation with per-thread configuration
- Streaming support for live interaction
- Shared thread backtracking support

- Debugging and clocking features
- Optional visual construction system for debugging and inspection
- Support for display optimizations


## Requirements for DIRECT execution

- Roblox Environment

## Developer note

- Major fixes and optimizations have been applied in V4, alongside the streaming support feature. There are still known syntax related issues to be fixed and incoming features to be implemented on V5.

### Future patch list

- Implementing enforcement settings for inter-thread merge operations
- Refactoring the object-oriented process architecture to improve flexibility
- Enhancing streaming capabilities
- Resolving multiple identified logical and performance issues
- Correcting and restructuring the lexical architecture of construction mode
