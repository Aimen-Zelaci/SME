# Ship game
![image](https://user-images.githubusercontent.com/53104539/233796601-a2dd8fb0-61e1-45c8-a485-2592f074cccc.png)

![image](https://user-images.githubusercontent.com/53104539/233796617-217a9cdf-1ce1-4b71-9e32-f26c63cdec21.png)

![image](https://user-images.githubusercontent.com/53104539/233796626-bcece499-7d7d-4469-8051-eac1153fff49.png)

![image](https://user-images.githubusercontent.com/53104539/233796640-93d9b376-b765-47bd-91e4-db0b41e6782d.png)


## Game play
- **Joystick (AD1)**: Moves ship up or down
- **Joystick (PB2)**: Press to start or restart game (when game won or over)
- **Keyboard button 8**: Moves ship up
- **Keyboard button 2**: Moves ship down
- **Keyboard button 5**: Shoots one bullet

## Code structure

Interrupt | Description 
---|:---:
Joystick Interrupt (PB2) | When the joystick is pressed the game state is incremented 
ADC conversion interrupt (AD1) &|Inside the value of the joystick is read and then a decision is made whether the joystick is up (move ship up state) or down  (move ship down state)
Timer 0 interrupt | The UPDATE\_BULLETSTATE is called in order to shift bullets
Timer 1 interrupt | Triggers the boss to shoot by writing a 1 to the boss\_shoot\_state variable. Moreover, a random number is generated for which gun (of the boss) will shoot
Timer 2 interrupt | Contains buzzer logic 


Address | Variable | Description 
---|:---:|---
0x0380 | BossShootStatus | Continously checked inside main. If 1 (0) the boss fires a bullet (doesn't), then reset to 0. Timer 1 Interrupt changes it's value to a 1. 
0x0381 | ShipLife | Stores how many life points the player has 
0x0382 | BossLife | Stores how many life points the boss has 
0x0383 | ScreenState | According to the value pointed by this value, a display decision to read from the character or screen buffer 
0x0384 |  JoystickState | Stores last state of joystick for change after two actions on interrupt  
0x0385 |  LastKey | Stores state of keyboard last pressed, in order to solve debouncing and continous button press issues 
0x0386 | RowIndex | Index used to count row number in display
0x0387 |  BuzzPattern | Key pattern for buzzer sound. Move up, move down, and shoot keys have different sounds.  
0x0388 |  RandomNumber | Address that holds value of random number to be generated, representing which gun of the boss to shoot 
0x0389 | UpState |  ADC interrupt writes a 1 (nothing) to it if the joystick is up (otherwise) 
0x0390 |  DownState | ADC interrupt writes a 1 (nothing) to it if the joystick is down (otherwise) 
0x0391 | MoveState | Toggled by Timer 0 interrupt. If 0 ADC interrupt does not write to UpState not DownState 
0x0392 | DownStateTimed | Continously checked within main: if 1 then the ship moves down a step and does not if 0. Timer 0 Interrupt writes 1 (0) to it if  DownState is 1 (0) 
0x0393 | UpStateTimed | Continously checked within main: if 1 then the ship moves up a step and does not if 0. Timer 0 Interrupt writes 1 (0) to it if  UpState is 1 (0) 
