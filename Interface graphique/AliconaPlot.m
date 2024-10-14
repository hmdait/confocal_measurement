
function AliconaPlot(data, varargin)
%
% ALICONAPLOT  receives a structure returned by AliconaReader, sets all NaN
% or similar values to 0 and plots the surface, the surface with its texture
% or only the texture, depending on what DATA contains. The DATA is sampled 
% by the optional parameter SAMPLING (default = 5). The grid is 1:xdim, 
% 1:ydim but can be SHIFTed.
%
% Syntax:
%   AliconaPlot(DATA)
%   AliconaPlot(DATA, SAMPLING)
%   AliconaPlot(DATA, SHIFT)
%   AliconaPlot(DATA, SAMPLING, SHIFT)
%
% Input:
%   DATA      = STRUCT containing an Alicona Header, depth and texture info
%   SAMPLING  = Scalar (integer)
%   SHIFT     = 3D Vector (double)
%
%
% Created by Martin Baiker on the 9th of January 2012
%
% 18-07-2012, line 51: [Y,X] = meshgrid ... -> [X,Y] = meshgrid ...

sampling = 5;
shift    = [0 0];

if nargin > 1
    if nargin == 2
        if size(varargin{1}, 1) == 1 && size(varargin{1}, 2) == 1
            sampling = varargin{1};
        else
            shift = varargin{1};
        end
    else
        sampling = varargin{1};
        shift    = varargin{2};
    end
end

depth   = 0;
texture = 0;
        
if isfield(data, 'TextureData')
    texture = 1;
end

if isfield(data, 'DepthData')
    depth = 1;
    [X,Y] = meshgrid(1:sampling:size(data.DepthData, 2) - 1, 1:sampling:size(data.DepthData, 1) - 1);
    Y = str2double(data.Header.PixelSizeYMeter) * Y + shift(2);
    X = str2double(data.Header.PixelSizeXMeter) * X + shift(1);
    tmp   = data.DepthData;  
    tmp(data.DepthData > 10000) = 0;
    
    % Interpolate the data to avoid artefacts at the boundaries
    
end

if texture && depth
    c_map = double(data.TextureData)./255;
    figure; hold on;
    surf(X, Y, double(tmp(1:sampling:end - 1, 1:sampling:end - 1)), ...
         c_map(1:sampling:end - 1, 1:sampling:end - 1, :), 'EdgeColor', 'none');

     daspect([1 1 1]); 
     view([-53, 40]);
     axis tight;
end

% if texture && ~depth
%     dipshow(data.TextureData);
%     dipshow(data.QualityMap);
% end
 
if ~texture && depth
    figure; hold on;
    surf(X, Y, double(tmp(1:sampling:end - 1, 1:sampling:end - 1)), 'EdgeColor', 'interp');

     daspect([1 1 1]); 
     view([-53, 40]);
     axis tight;     
end
 


 