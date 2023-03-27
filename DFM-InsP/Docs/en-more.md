Set the averaging mode for variable Sn in this sub-menu - Choose __Global
Average__ mode to average Sn from app start or reset, or __Running Average__ mode
to compute a \'sliding window average\' over N samples. N is also set here.

The choice of averaging mode and N control the behavior of the avgV(\'Sn\')
function anywhere it is used in a lua expression in the app and is based on the
settings for the lua variable Sn.

Please note that the control of how a lua variable e\.g\. Sn is averaged is a
property of the variable Sn itself and will determine the output of the
avgV(\'Sn\') function wherever it is called.

For example if the function avgV(\'S4\') is included in the lua expression to
define variable S1, it is the averaging settings for S4 that will determine the
behavior of the avgV(\'S4\') function that is returned to the expression
defining S1.

See the help file one level up for more information on functions.

