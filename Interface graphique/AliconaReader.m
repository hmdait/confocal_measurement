
function [data, varargout] = AliconaReader(varargin)

%  ALICONAREADER  opens an AL3D file from the Alicona IFM and returns a
%  DATA structure containing a header and the following (if present): icon,
%  depth and texture data. The PATH can be passed. Otherwise, a select file
%  dialog box appears.
%  
%   Syntax:
%     DATA = AliconaReader()
%     DATA = AliconaReader(PATH)
%     [DATA, PARAM] = AliconaReader()
%     [DATA, PARAM] = AliconaReader(PATH)
%  
%   Input:
%     PATH  = String
%
%   Output:
%     DATA  = Struct, containing a header and, if available, data
%     PARAM = Parameter structure
%  
%   Created by Martin Baiker on the 9th of January 2012
%   
%   

if nargin == 0;
    [filename, pathname] = uigetfile('*.al3d', 'Select the file to open', 'E:\NFI_Project\3D_IFM_data_analysis\Gedore_SD_data');
else
    tmp = strfind(varargin{1}, '\');
    filename = varargin{1}(tmp(end)+1:end);
    pathname = varargin{1}(1:tmp(end));
end

path = [pathname filename];

data = struct;
tags = struct;

fid = fopen(path, 'r');




%% Read the header

% Determine the key-value pair
tmp   = char(fread(fid, 17, 'char'));
tmp2  = find(uint8(tmp') == 0);
tags.Type   = tmp(1:tmp2-1)';

% Determine the key-value pair
tmp   = char(fread(fid, 52, 'char'));
tmp2  = find(uint8(tmp(21:50)') ~= 0);
value = tmp(tmp2 + 20)';
tags.Version = value;

% Determine the key-value pair
tmp   = char(fread(fid, 52, 'char'));
tmp2  = find(uint8(tmp(21:50)') ~= 0);
value = tmp(tmp2 + 20)';
tags.Counter = value;


for tag_num = 1:1:str2double(tags.Counter)
    tmp = char(fread(fid, 52, 'char'));
    %disp(tmp');
    
    % Determine the key-value pair
    tmp2  = find(uint8(tmp(1:20)') ~= 0);
    key   = tmp(tmp2)';
    tmp2  = find(uint8(tmp(21:50)') ~= 0);
    value = tmp(tmp2 + 20)';
    
    tags.(sprintf('%s', key)) = value;
end

% Read the comment
tags.Comment = char(fread(fid, 256, 'char'));


data.Header = tags;




%% Read the icon data
% Check if there is an icon in the data file
if str2double(tags.IconOffset) > 0
    status              = fseek(fid, str2double(tags.IconOffset), 'bof');
    icon_data           = zeros(152, 150, 3, 'uint8');
    icon_data(:,:,1)    = reshape(fread(fid, 22800, 'uint8'), ...
                               152, 150);
    icon_data(:,:,2)    = reshape(fread(fid, 22800, 'uint8'), ...
                               152, 150);
    icon_data(:,:,3)    = reshape(fread(fid, 22800, 'uint8'), ...
                               152, 150);
    data.Icon           = icon_data;
else

    % Check if there is an icon file in the current directory
    if exist([pathname 'icon.bmp'], 'file')
        icon_data = imread([pathname 'icon.bmp']);
        data.Icon = icon_data;
    end
end
    


%% Read the depth data
if str2double(tags.DepthImageOffset) > 0
    %status          = fseek(fid, str2double(tags.DepthImageOffset), 'bof');
    rows            = str2double(tags.Rows);

    % The columns should be calculated instead of taking the amount from
    % the tag, because if the amount of columns is not dividable by 8, the 
    % remaining columns will be padded so that the total amount is
    % dividable by 8    
    if str2double(tags.TextureImageOffset) == 0 
        fseek(fid, 0, 'eof');
        cols    = (ftell(fid) - str2double(tags.DepthImageOffset))./(4 * rows); 
    else
        cols    = (str2double(tags.TextureImageOffset) - str2double(tags.DepthImageOffset))./(4 * rows); 
    end        
    
    % Cols is the x-dimension and rows the y-dimension
    fseek(fid, str2double(tags.DepthImageOffset), 'bof');
    depth_data      = zeros(cols, rows, 1, 'single');
    depth_data(:,:) = reshape(fread(fid, cols * rows, 'float'), ...
                              cols, rows);
                          
    depth_data      = depth_data(1:end-(cols - str2double(data.Header.Cols)), :);

    % Bring the data in an image coordinate frame (like the DIPImage frame)    
    data.DepthData  = single(rot90(depth_data));
end



%% Read the texture data
% Check if there is a texture image in the data file
if str2double(tags.TextureImageOffset) > 0
    %status              = fseek(fid, str2double(tags.TextureImageOffset), 'bof');
    
    rows            = str2double(tags.Rows);
    
    if strcmp(data.Header.TexturePtr, '0;1;2')
        amount_of_planes = 4;
    else
        amount_of_planes = 1;
    end

    fseek(fid, 0, 'eof');
    cols    = (ftell(fid) - str2double(tags.TextureImageOffset))./(amount_of_planes * rows); 

    fseek(fid, str2double(tags.TextureImageOffset), 'bof');
    texture_data        = zeros(cols, rows, amount_of_planes, 'uint8');
    for plane = 1:1:amount_of_planes
        texture_data(:,:,plane) = reshape(fread(fid, cols * rows, 'uint8'), ...
                                          cols, rows);
    end                       
                
    texture_data        = texture_data(1:end-(cols - ...
                                    str2double(data.Header.Cols)), :, :);                   
        
    %texture_data        = permute(texture_data, [2 1 3]);
    % ans = fread(fid, inf, 'uint8'); 
    % position = ftell(fid);

    data.TextureData        = texture_data(:,:,1:3);
    data.QualityMap         = texture_data(:,:,4);
    %data.TextureAlignment   = texture_alignment;
  
else
    % Check if there is a texture image in the current directory
    if exist([pathname 'texture.bmp'], 'file')        
        texture_data     = imread([pathname 'texture.bmp']);
        % Bring the data in an image coordinate frame    
        %data.TextureData = uint8(mirror(texture_data, 'y-axis'));
        data.TextureData = texture_data;
        data.TextureData(:,:,1) = uint8(data.TextureData(end:-1:1, :, 1));
        data.TextureData(:,:,2) = uint8(data.TextureData(end:-1:1, :, 2));
        data.TextureData(:,:,3) = uint8(data.TextureData(end:-1:1, :, 3));
    end
    if exist([pathname 'texture.png'], 'file')        
        texture_data     = imread([pathname 'texture.png']);
        % Bring the data in an image coordinate frame   
        %data.TextureData = uint8(mirror(texture_data, 'y-axis'));
        data.TextureData = texture_data;
        data.TextureData(:,:,1) = uint8(data.TextureData(end:-1:1, :, 1));
        data.TextureData(:,:,2) = uint8(data.TextureData(end:-1:1, :, 2));
        data.TextureData(:,:,3) = uint8(data.TextureData(end:-1:1, :, 3));        
    end  
    
    if exist([pathname 'qualitymap.bmp'], 'file')
        qualitymap      = imread([pathname 'qualitymap.bmp'])';
        % Bring the data in an image coordinate frame
        data.QualityMap = uint8(rot90(qualitymap));
    end
    if exist([pathname 'qualitymap.png'], 'file')
        qualitymap      = imread([pathname 'qualitymap.png'])';
        % Bring the data in an image coordinate frame 
        data.QualityMap = uint8(rot90(qualitymap));
    end
end



%% Read additional data from an XML file
% Check if there is an XML file in the current directory
if exist([pathname 'info.xml'], 'file')
    xml_data = AliconaXMLReader([pathname 'info.xml']);
    data.XMLData = xml_data;
end

fclose(fid);


param = struct;
param.xdim          = str2double(data.Header.PixelSizeXMeter);
param.resolution    = str2double(data.Header.PixelSizeXMeter) * 1e6;
param.ydim          = str2double(data.Header.PixelSizeYMeter);
param.root_folder   = pathname;

if nargout == 2
    varargout{1} = param;
end
