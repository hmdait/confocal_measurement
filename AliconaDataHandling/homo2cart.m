
function MATRIX_EUCL = homo2cart(DATA)
%
% homo2cart   converts homogeneous to euclidean data
%
% Syntax:
%   MATRIX_EUCL = HOMO2CART(DATA)
%   
% Description:
%   MATRIX_EUCL = HOMO2CART(DATA) converts a dataset in homogeneous space 
%   (nx4) to euclidean space (nx3)
%

if length(DATA(1,:)) == 4
    MATRIX_EUCL = DATA(:, 1:3);
elseif sum(DATA(:,end)) == length(DATA(:,end))
    MATRIX_EUCL = DATA(:, 1:2);
else
    MATRIX_EUCL = DATA;
end