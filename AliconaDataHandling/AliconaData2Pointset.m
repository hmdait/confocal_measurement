
function pointset = AliconaData2Pointset(data, varargin)
%
% ALICONADATA2POINTSET  receives a structure returned by AliconaReader, sets
% all NaN or similar values to 0 and converts the data to a 3D pointset, 
% sampled with the optional parameter SAMPLING (default = 5) and optionally
% TRANSFORMed.
%
% Syntax:
%   AliconaPlot(DATA)
%   AliconaPlot(DATA, SAMPLING)
%   AliconaPlot(DATA, TRANSFORM
%   AliconaPlot(DATA, SAMPLING, TRANSFORM)
%
% Input:
%   DATA      = STRUCT containing an Alicona Header, depth and texture info
%   SAMPLING  = Scalar (integer)
%   TRANSFORM = 4x4 Matrix (double)
%
%
% Created by Martin Baiker on the 16th of May 2012
%
%

sampling        = 5;
transformation  = eye(4);

if nargin > 1
    if nargin == 2
        if size(varargin{1}, 1) == 1 && size(varargin{1}, 2) == 1
            sampling = varargin{1};
        else
            transformation = varargin{1};
        end
    else
        sampling = varargin{1};
        transformation    = varargin{2};
    end
end

[Y,X] = meshgrid(1:sampling:size(data.DepthData, 2) - 1, 1:sampling:size(data.DepthData, 1) - 1);
Y = str2double(data.Header.PixelSizeYMeter) * Y;
X = str2double(data.Header.PixelSizeXMeter) * X;
tmp   = data.DepthData;  
%tmp(data.DepthData > 10000) = -8e-4;
tmp(data.DepthData > 10000) = median(data.DepthData(:));

tmp = patch(X, Y,   double(tmp(1:sampling:end - 1, 1:sampling:end - 1)), ...
                    double(tmp(1:sampling:end - 1, 1:sampling:end - 1)), ...
                    'Visible', 'off');

pointset = get(tmp, 'Vertices');
pointset = TransformPointset(pointset, transformation);
    

 


 