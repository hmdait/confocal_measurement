
function MATRIX_HOMO = cart2homo(DATA)
%
% cart2homo   converts euclidean to homogeneous data
%
% Syntax:
%   MATRIX_HOMO = CART2HOMO(DATA)
%   
% Description:
%   MATRIX_HOMO = CART2HOMO(DATA) converts a dataset in euclidean space 
%   (nx3) to homogeneous space (nx4)
%

if length(DATA(1,:)) < 4
    MATRIX_HOMO = [DATA ones(length(DATA(:,1)), 1)];
else
    MATRIX_HOMO = DATA;
end