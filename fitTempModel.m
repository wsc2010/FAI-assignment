function [y1] = fitTempModel(x1)
%FITTEMPMODEL neural network simulation function.
%
% Auto-generated by MATLAB, 13-Feb-2022 00:17:09.
% 
% [y1] = fitTempModel(x1) takes these arguments:
%   x = 4xQ matrix, input #1
% and returns:
%   y = 1xQ matrix, output #1
% where Q is the number of samples.

%#ok<*RPMT0>

% ===== NEURAL NETWORK CONSTANTS =====

% Input 1
x1_step1.xoffset = [0;0;13;-0.6];
x1_step1.gain = [0.0208333333333333;0.0202020202020202;0.0668896321070234;0.0696864111498258];
x1_step1.ymin = -1;

% Layer 1
b1 = [3.5485526754471865551;-2.7444532026459431684;1.4194978638499358148;-0.98799643659222025072;-0.080963786478840102379;1.1565031258578708506;-0.038315709333189812424;1.3589731419521782207;2.0418797403169524074;1.6380497468752217571];
IW1_1 = [-0.75607055736639572352 -2.4020803169939122235 -2.0822992148401295864 0.31535338394904105508;1.1139278277067747869 2.247202197051883843 -0.71037648361147009979 -0.82239771287369245467;-1.1133385986887081032 -0.98952149521503784957 1.4808090886835647559 -0.41164389194575495834;-2.1071955189144957465 3.6037690272710820594 -2.6593252761630838954 -1.2777238222896387665;0.75056400178814763891 -0.92583670372501614132 -0.70423634501624599036 -1.9139546572135097691;2.0731319901694997831 -0.84560773951898937639 2.0533498606997944158 -1.1908347203577180906;1.624512009238489707 -0.092991732787640349334 1.1746958769651354437 0.62047835928087646806;0.75155203466990161409 -1.3130059240454978742 -1.477578480061083166 -0.4594839223726667754;1.7358933667316811533 0.45994339673250994593 -0.16719365697491025968 0.68451519292745466316;-0.21925592965465043327 0.31710635997933789287 -0.74016425994338852501 1.6103089060761346385];

% Layer 2
b2 = -0.16571929302054635991;
LW2_1 = [-0.73799243694523830595 -0.093432322197827669119 0.11654968030123621925 -0.0035645099767946247793 -0.20633847198224730679 0.37534874609621166064 -0.083935006714983675935 -0.21310345858935814123 -0.51771273378406057475 1.1655313216947016386];

% Output 1
y1_step1.ymin = -1;
y1_step1.gain = 0.0649350649350649;
y1_step1.xoffset = 5.6;

% ===== SIMULATION ========

% Dimensions
Q = size(x1,2); % samples

% Input 1
xp1 = mapminmax_apply(x1,x1_step1);

% Layer 1
a1 = tansig_apply(repmat(b1,1,Q) + IW1_1*xp1);

% Layer 2
a2 = repmat(b2,1,Q) + LW2_1*a1;

% Output 1
y1 = mapminmax_reverse(a2,y1_step1);
end

% ===== MODULE FUNCTIONS ========

% Map Minimum and Maximum Input Processing Function
function y = mapminmax_apply(x,settings)
  y = bsxfun(@minus,x,settings.xoffset);
  y = bsxfun(@times,y,settings.gain);
  y = bsxfun(@plus,y,settings.ymin);
end

% Sigmoid Symmetric Transfer Function
function a = tansig_apply(n,~)
  a = 2 ./ (1 + exp(-2*n)) - 1;
end

% Map Minimum and Maximum Output Reverse-Processing Function
function x = mapminmax_reverse(y,settings)
  x = bsxfun(@minus,y,settings.ymin);
  x = bsxfun(@rdivide,x,settings.gain);
  x = bsxfun(@plus,x,settings.xoffset);
end
