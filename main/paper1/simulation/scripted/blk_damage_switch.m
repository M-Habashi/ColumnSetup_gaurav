function alpha = blk_damage_switch(t, considerDamage, alphaMin, alphaStart)
%BLK_DAMAGE_SWITCH Select legacy degradation or the initial stiffness.

if nargin < 4
    alphaStart = 1;
end
if considerDamage == 1
    alpha = blk_alpha_profile(t, alphaMin, alphaStart);
else
    alpha = alphaStart;
end
end
