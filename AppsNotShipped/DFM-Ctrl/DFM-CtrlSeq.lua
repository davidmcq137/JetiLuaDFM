--
-- self-describing data for DFM-Ctrl.lua
--


CTRL_n {
   "L_Ail", "R_Ail", "L_Flap", "R_Flap", "L_Rud", "R_Rud", "L_Ele", "R_Ele"
}

CTRL_sn {
   "L_A", "R_A", "L_F", "R_F", "L_R", "R_R", "L_E", "R_E"
}

CTRL_st {
   {dt=500, L_Ail=0 ,R_Ail=0, L_Flap=1, R_Flap=1, L_Rud=0, R_Rud=0, L_Ele=0, R_Ele=0},
   
   {dt=500, L_Ail=1 ,R_Ail=1, L_Flap=1, R_Flap=1, L_Rud=0, R_Rud=0, L_Ele=0, R_Ele=0}, 
   {dt=1000,L_Ail=-1,R_Ail=-1,L_Flap=1, R_Flap=1, L_Rud=0, R_Rud=0, L_Ele=0, R_Ele=0}, 
   {dt=500, L_Ail=0 ,R_Ail=0 ,L_Flap=1, R_Flap=1, L_Rud=0, R_Rud=0, L_Ele=0, R_Ele=0},

   {dt=500, L_Ail=1 ,R_Ail=-1,L_Flap=1, R_Flap=1, L_Rud=0, R_Rud=0, L_Ele=0, R_Ele=0}, 
   {dt=1000,L_Ail=-1,R_Ail=1 ,L_Flap=1, R_Flap=1, L_Rud=0, R_Rud=0, L_Ele=0, R_Ele=0}, 
   {dt=500, L_Ail=0 ,R_Ail=0 ,L_Flap=1, R_Flap=1, L_Rud=0, R_Rud=0, L_Ele=0, R_Ele=0},

   {dt=1000,L_Ail=0 ,R_Ail=0 ,L_Flap=1, R_Flap=1, L_Rud=0, R_Rud=0, L_Ele=0, R_Ele=0},

   {dt=500, L_Ail=0 ,R_Ail=0 ,L_Flap=0, R_Flap=0, L_Rud=0, R_Rud=0, L_Ele=0, R_Ele=0},
   {dt=1000,L_Ail=0 ,R_Ail=0 ,L_Flap=-1,R_Flap=-1,L_Rud=0, R_Rud=0, L_Ele=0, R_Ele=0},
   {dt=500, L_Ail=0 ,R_Ail=0 ,L_Flap=1, R_Flap=1, L_Rud=0, R_Rud=0, L_Ele=0, R_Ele=0},

   {dt=1000,L_Ail=0 ,R_Ail=0 ,L_Flap=1, R_Flap=1, L_Rud=0, R_Rud=0, L_Ele=0, R_Ele=0},

   {dt=500, L_Ail=0 ,R_Ail=0 ,L_Flap=1, R_Flap=1, L_Rud=1, R_Rud=1, L_Ele=0, R_Ele=0},
   {dt=1000,L_Ail=0 ,R_Ail=0 ,L_Flap=1, R_Flap=1, L_Rud=-1,R_Rud=-1,L_Ele=0, R_Ele=0},
   {dt=500, L_Ail=0 ,R_Ail=0 ,L_Flap=1, R_Flap=1, L_Rud=0, R_Rud=0, L_Ele=0, R_Ele=0},
   
   {dt=1000,L_Ail=0 ,R_Ail=0 ,L_Flap=1, R_Flap=1, L_Rud=0, R_Rud=0, L_Ele=0, R_Ele=0},

   {dt=500, L_Ail=0 ,R_Ail=0 ,L_Flap=1, R_Flap=1, L_Rud=-1,R_Rud=1, L_Ele=0, R_Ele=0},
   {dt=1000,L_Ail=0 ,R_Ail=0 ,L_Flap=1, R_Flap=1, L_Rud=1, R_Rud=-1,L_Ele=0, R_Ele=0},
   {dt=500, L_Ail=0 ,R_Ail=0 ,L_Flap=1, R_Flap=1, L_Rud=0, R_Rud=0, L_Ele=0, R_Ele=0},

   {dt=1000,L_Ail=0 ,R_Ail=0 ,L_Flap=1, R_Flap=1, L_Rud=0, R_Rud=0, L_Ele=0, R_Ele=0},

   {dt=500, L_Ail=0 ,R_Ail=0 ,L_Flap=1, R_Flap=1, L_Rud=0, R_Rud=0, L_Ele=1, R_Ele= 1},
   {dt=500, L_Ail=0 ,R_Ail=0 ,L_Flap=1, R_Flap=1, L_Rud=0, R_Rud=0, L_Ele=0, R_Ele= 0},
   {dt=500, L_Ail=0 ,R_Ail=0 ,L_Flap=1, R_Flap=1, L_Rud=0, R_Rud=0, L_Ele=-1,R_Ele=-1},
   {dt=500, L_Ail=0 ,R_Ail=0 ,L_Flap=1, R_Flap=1, L_Rud=0, R_Rud=0, L_Ele=0, R_Ele= 0},
   
   {dt=1000,L_Ail=0 ,R_Ail=0 ,L_Flap=1, R_Flap=1, L_Rud=0, R_Rud=0, L_Ele=0, R_Ele=0},

   {dt=500, L_Ail=0 ,R_Ail=0 ,L_Flap=1, R_Flap=1, L_Rud=0, R_Rud=0, L_Ele=1, R_Ele=-1},
   {dt=500, L_Ail=0 ,R_Ail=0 ,L_Flap=1, R_Flap=1, L_Rud=0, R_Rud=0, L_Ele=0, R_Ele= 0},
   {dt=500, L_Ail=0 ,R_Ail=0 ,L_Flap=1, R_Flap=1, L_Rud=0, R_Rud=0, L_Ele=-1,R_Ele= 1},
   {dt=500, L_Ail=0 ,R_Ail=0 ,L_Flap=1, R_Flap=1, L_Rud=0, R_Rud=0, L_Ele=0, R_Ele= 0},   
}
