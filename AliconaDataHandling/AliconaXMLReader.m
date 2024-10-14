
function xml_tree = AliconaXMLReader(varargin)

%  XML_TREE = ALICONAXMLREADER(VARARGIN) parses an Alicona XML file created
%  by the IFM and returns a data structure XML_TREE, containing all fields
%  in the XML file. Note that this routine is tailored for the Alicona XML
%  file and will probably not work for general XML files. Strings in tag
%  openers will only be processed, if there is no tag value present.
%
%  Tag = A data field including tag opener (between '<' '>'), tag value and
%        tag closer ('</' '>'). Alternatively, a tag can consist of simply 
%        one string between '<' '/>' i.e. including tag name and value.  
%
%   Syntax:
%     AliconaXMLReader()
%     AliconaXMLReader(PATH)
%  
%   Input:
%     PATH      = String
%     XML_TREE  = Struct, containing the data fields in the specified xml
%                 file
%  
%   Created by Martin Baiker on the 10th of January 2012
%   Updated by Martin Baiker on the 1st of March 2016
%   

    if nargin == 0;
        [filename, pathname] = uigetfile('*.xml', 'Select the file to open');
    else
        tmp = findstr(varargin{1}, '\');
        filename = varargin{1}(tmp(end)+1:end);
        pathname = varargin{1}(1:tmp(end));
    end

    path = fullfile(pathname, filename);

    % Open the xml file and read all contents, including all spaces
    fid = fopen(path, 'r');
    A   = fscanf(fid, '%c', inf);

    fclose(fid);

    % This variable will be used to always know where we are along the xml 
    % string
    xml_tree    = struct;
    
    read_entire_content = 0;
    if read_entire_content
        % The string counter was declared in the function as persistent.
        % Therefore the first call has to initialize it to 1.
        reset_count = 1;
        xml_tree    = add_next_tag2struct(xml_tree, A, reset_count);
    else
        start_LR = findstr(A, 'Estimated Lateral Resolution');
        start_VR = findstr(A, 'Estimated Vertical Resolution');
        
        if isempty(start_LR)
            xml_tree.Object3D.generalData.description.Estimated_Lateral_Resolution = [];
            xml_tree.Object3D.generalData.description.Estimated_Vertical_Resolution = [];
        else
            start_VR = start_VR + 30;
            start_LR = start_LR + 29;

            while double(A(start_LR)) == 32
                start_LR = start_LR + 1;
            end

            while double(A(start_VR)) == 32
                start_VR = start_VR + 1;
            end

            tmp  = find(double(A) == 13);

            tmp2 = find(tmp > start_LR);
            xml_tree.Object3D.generalData.description.Estimated_Lateral_Resolution = A(start_LR:tmp(tmp2(1))-1);

            tmp2 = find(tmp > start_VR);
            xml_tree.Object3D.generalData.description.Estimated_Vertical_Resolution = A(start_VR:tmp(tmp2(1))-1);
        end
    end
end



function tree = add_next_tag2struct(tree, varargin)

    persistent count;
    
    if nargin == 2
        if isempty(count)
            count = 1;
        end
    else
        count = 1;
    end
        
    str = varargin{1};
    
    % This function parses through the entire string contained in the XML
    % file and recursively extracts the tag names and values and stores it
    % in a Matlab structure.
    % Note that after processing of this function, count is set such that
    % the beginning of the next tag in the string can be found by searching
    % for the subsequent '<' character (that does not belong to the tag 
    % ending '</').
    
    
    % Find the beginning of the next tag
    while ~strcmp(str(count), '<')
        count = count + 1;
    end

    % Get the name of the tag i.e. the string between '<' and '>' or
    % alternatively between '<' and the first ' '
    new_tag = find_tag_name(str, count);
    
    % Find the end of this tag
    end_tag       = find_end_tag(str, count);

    % Find the end of the tag value of this tag
    begin_tag_value = end_tag + 1; 
    tmp             = strfind(str, ['</' new_tag]);
    
    % Sometimes, tag values are included in the tag itself i.e. between '<'
    % and '>'. In this case, the tag is closed using '/>'
    if isempty(tmp)
        
        % If the tag value is included in the tag itself, the entire string
        % is saved as value of the current tag
        tmp     = strfind(str, '/>');
        indices = find(tmp > count);
        end_tag_value   = tmp(indices(1));
        if ~isfield(tree, new_tag)
            tree.(sprintf('%s', new_tag)) = struct;
        end
        tree.(sprintf('%s', new_tag)) = str(count+size(new_tag, 2) + 2:end_tag_value-1);
        
        % Set the counter to the first position following the terminating
        % '>' of the current tag closer
        count = end_tag_value + 2;
    else
        
        indices         = find(tmp > count);
        end_tag_value   = tmp(indices(1));

        % Sometimes, tags can have multiple tag 'children' with identical
        % names like e.g. matrix often has multiple kids called vector.
        % Since it is not possible to have multiple fields in a structure
        % with the same name, we manually name them.... in the XML files of
        % Alicona, only 4x4 matrices occur and therefore it is possible to
        % do this quick and dirty.
        if strcmp(new_tag, 'vector')
            if ~isfield(tree, [new_tag '1'])
                new_tag = 'vector1';
            else
                if ~isfield(tree, [new_tag '2'])
                    new_tag = 'vector2';
                else
                    if ~isfield(tree, [new_tag '3'])
                        new_tag = 'vector3';
                    else
                        new_tag = 'vector4';
                    end
                end
            end
        end

        % Set the counter to the first position following the terminating
        % '>' of the current tag opener
        count = begin_tag_value;

        % Some tags do not have any value... assign '' instead
        if count == end_tag_value
            tree.(sprintf('%s', new_tag)) = '';
            count = find_end_tag(str, end_tag_value) + 1;
        end

        
        
        % For normal tags,  including tag opener (between '<' '>'), tag value and
        % tag closer ('</' '>'), proceed to obtain its value
        while count < end_tag_value
            
            % Skip all lf, cr and spaces at the beginning of a tag value
            while uint8(str(count)) == 13 || uint8(str(count)) == 10 || ...
                  uint8(str(count)) == 32
                count = count + 1;               
            end

            % If we reach the end of the tag value after skipping all lfs, crs and
            % spaces, the tag value will be set to ''
            if count == end_tag_value
                if ~isfield(tree, new_tag)
                    tree.(sprintf('%s', new_tag)) = '';
                end
                count = find_end_tag(str, end_tag_value) + 1;
            else
                % Check if the value is a tag itself of just a value. If it
                % is a tag, this function is called recursively and the tag
                % added as a structure field. If it is a value, this will
                % be assigned to the current structure field.
                if strcmp(str(count), '<')
                    % Check, if the current tag is already present. This is
                    % important after adding tag children to a tag and
                    % coming back to the tag mother. Without this check,
                    % the tag mother would be overwritten.
                    if ~isfield(tree, new_tag)
                        tree.(sprintf('%s', new_tag)) = struct;
                    end
                    tree.(sprintf('%s', new_tag)) = add_next_tag2struct(...
                                    tree.(sprintf('%s', new_tag)), str);
                else
                    % In the Alicona XML file, the 'description' tag
                    % contains a lot of data, separated by '&#xd'. To make
                    % this more readable, 'description' is converted to a
                    % structure with the individual parameters as fields.
                    if strcmp(new_tag, 'description')
                        tree.(sprintf('%s', new_tag)) = struct;
                        
                        % The string counter was declared in the function 
                        % as persistent. Therefore the first call has to 
                        % initialize it to 1.
                        reset_count = 1;
                        tree.(sprintf('%s', new_tag)) = ...
                                    get_description_structure(...
                                         tree.(sprintf('%s', new_tag)), ...
                                         str(count:end_tag_value-1), reset_count);
                    else
                        tree.(sprintf('%s', new_tag)) = str(count:end_tag_value-1);
                    end
                    
                    % After adding the tag value, the counter has to be set
                    % to a position after the '<' of the tag closer because
                    % the current tag has been processed. The condition '
                    % count < end_tag_value' above makes sure that this tag
                    % is not processed further
                    count = find_end_tag(str, end_tag_value) + 1;
                end
            end
        end
    end
end



function tag_name = find_tag_name(str, count)

    % This function simply determines the tag name in the tag opener

    t = 1;

    while ~strcmp(str(count + t), ' ') && ~strcmp(str(count + t), '>')
        t = t + 1;
    end

    tag_name = str(count + 1:count + t - 1);

end


function end_tag = find_end_tag(str, count)

    % This function simply determines the end of a tag opener or closer

    t = 1;

    while ~strcmp(str(count + t), '>')
        t = t + 1;
    end

    end_tag = count + t;

end


function description_structure = ...
            get_description_structure(description_structure, varargin)

    persistent parser;
    
    if nargin == 2
        if isempty(parser)
            parser = 1;
        end
    else
        parser = 1;
    end
        
    input_string = varargin{1};

    
    % This function converts the parameters in the description tag to a 
    % description structure with the parameters as fields.
    % There are actually two sublevels present. One is indicated by a
    % stopping sequence '&#xd;' right after the parameter name and the
    % other by a horizontal tab before the parameter name. It cannot be
    % derived from the string, when the first level ends and therefore, 
    % those parameter(s), which are rather labels and do not possess
    % values, are simply discarded. The second sublevel is treated as first
    % sublevel and the end of this sublevel is found when there is no
    % horizontal tab in front of the next parameter name in the string.    
    % Note that after processing this function, the parser is always set to
    % the next following character after the terminator string '&#xd;'
    
    end_sublevel = 0;
    
    while  parser <= size(input_string, 2) && ~end_sublevel
            
        end_sublevel = 0;
        
        new_field_found = 1;
        
        % Skip all lf, cr and spaces at the beginning of a field name. Also
        % skip empty lines, indicated by '&#xd;'
        while (uint8(input_string(parser)) == 13 || ...
               uint8(input_string(parser)) == 10 || ...
               uint8(input_string(parser)) == 32 || ~new_field_found)
            parser = parser + 1;
            new_field_found = 1;

            if strcmp(input_string(parser:parser + 4), '&#xd;')
                new_field_found = 0;
                parser = parser + 5;
            end
        end
            
        begin_field_name = parser;

        % Extract the fieldnames, that are terminated by ':'
        while ~strcmp(input_string(parser), ':')
            parser = parser + 1;
        end

        end_field_name = parser - 1;

        parser = parser + 1;

        fieldname = input_string(begin_field_name:end_field_name);

        % Remove spaces and '-' characters because these are invalid in
        % structure field names in Matlab
%         for character = 1:1:size(fieldname, 2)
%             if strcmp(fieldname(character), ' ') || strcmp(fieldname(character), '-') || strcmp(fieldname(character), '!')
%                 fieldname(1, character) = '_';
%             end
%         end
        % UPDATED VERSION: Only letters and tabs are allowed in the
        % filename. (Tabs are required to detect second level fields and are removed later in the code).
        for character = 1:1:size(fieldname, 2)
            if ~((uint8(fieldname(character)) >= 65 && uint8(fieldname(character)) <= 90 || ...
                  uint8(fieldname(character)) >= 97 && uint8(fieldname(character)) <= 122) || ...
                  uint8(fieldname(character)) == 9)
                fieldname(1, character) = '_';
            end
        end
        
        % Avoid an underscore at the end of a fieldname
        if strcmp(fieldname(end), '_')
            while strcmp(fieldname(end), '_')
                fieldname = fieldname(1:end-1);
            end
        end
         
        while uint8(input_string(parser)) == 13 || uint8(input_string(parser)) == 10 || ...
              uint8(input_string(parser)) == 32
            parser = parser + 1;
        end
        
        tmp = strfind(input_string(parser:end), '&#xd;');
        
        if ~isempty(tmp)
            
            % If the terminator '&#xd;' follows the ':' instantly, this
            % indicates a sublevel
            if tmp(1) == 1
                
                % In this case, there is no value for this field but the 'values'
                % are fields themselves -> recursively add the fields
                % Fields within fields are indicated in two ways: either the
                % combination '&#xd;' follows the ':' without characters in
                % between or a horizontal tab is included
                parser = parser + 5;

                % Check, if the following field is tabbed. If not, discard this
                % tab
                tmp_parser = parser;
                new_field_found = 1;
                while (uint8(input_string(tmp_parser)) == 13 || ...
                       uint8(input_string(tmp_parser)) == 10 || ...
                       uint8(input_string(tmp_parser)) == 32 || ~new_field_found)
                    tmp_parser = tmp_parser + 1;
                    new_field_found = 1;

                    if strcmp(input_string(tmp_parser:tmp_parser + 4), '&#xd;')
                        new_field_found = 0;
                        tmp_parser = tmp_parser + 5;
                    end
                end
                
                end_sequences = strfind(input_string(tmp_parser:end), '&#xd;');

                % Only add this sublevel parameter, if it belongs to the
                % second sublevel i.e. if there is a horizontal tab 
                % (ASCII = 9) before the parameter name. Otherwise, simply
                % skip the parameter, which is then in fact a label
                if uint8(input_string(tmp_parser)) == 9
                    if ~isfield(description_structure, fieldname)
                        description_structure.(sprintf('%s', fieldname)) = struct;
                    end

                    % The current parameter value is a structure instead of
                    % just a value. Therefore, recursively determine the
                    % contents of the structure.
                    description_structure.(sprintf('%s', fieldname)) = struct;
                    description_structure.(sprintf('%s', fieldname)) = ...
                      get_description_structure(description_structure.(sprintf('%s', fieldname)), ...
                                                input_string);
                else
                    % In the new SL systems, fieldname-value pairs are not
                    % consistently in one line, separated with a ':' and
                    % ending on '&#xd;', but sometimes the value is given
                    % in a new line, while there is a '&#xd;' at the end of
                    % the fieldname, hence it looks like a label. In case
                    % there is a letter after '&#xd;' and there is NO ':'
                    % before the next '&#xd;', this is a value
                    if (uint8(input_string(tmp_parser)) >= 65 && uint8(input_string(tmp_parser)) <= 90 || ...
                       uint8(input_string(tmp_parser)) >= 97 && uint8(input_string(tmp_parser)) <= 122) && ...
                       isempty(strfind(input_string(tmp_parser:tmp_parser + end_sequences(1) - 2), ':'))
                        description_structure.(sprintf('%s', fieldname)) = input_string(tmp_parser:tmp_parser + end_sequences(1) - 2);
                        parser = tmp_parser + end_sequences(1) + 4;
                    end
                end
            else
                
                % If we are processing the second sublevel and there is no
                % new sublevel indicator (ASCII = 9) in front of the
                % subsequent parameter, set a flag 'end_sublevel' that
                % causes the sublevel processing to be aborted.
                if uint8(fieldname(1)) == 9
                    parser = parser + 1;
                    fieldname = fieldname(2:end);

                    % Check, if the following field is also tabbed. If not,
                    % leave the level
                    tmp_parser = parser + tmp(1) + 3;
                    new_field_found = 1;
                    while (uint8(input_string(tmp_parser)) == 13 || ...
                           uint8(input_string(tmp_parser)) == 10 || ...
                           uint8(input_string(tmp_parser)) == 32 || ~new_field_found)
                        tmp_parser = tmp_parser + 1;
                        new_field_found = 1;

                        if strcmp(input_string(tmp_parser:tmp_parser + 4), '&#xd;')
                            new_field_found = 0;
                            tmp_parser = tmp_parser + 5;
                        end
                    end

                    if uint8(input_string(tmp_parser)) ~= 9
                        end_sublevel = 1;
                    end
                end

                % Add the parameter value to the parameter name
                description_structure.(sprintf('%s', fieldname)) = struct;
                    description_structure.(sprintf('%s', fieldname)) = ...
                                                    input_string(parser:parser + tmp(1) - 2);

                parser = parser + tmp(1) + 4;
            end
        else
            description_structure.(sprintf('%s', fieldname)) = struct;
            
            tmp = strfind(input_string(parser:end), '<');
            description_structure.(sprintf('%s', fieldname)) = ...
                                                    input_string(parser:end);

            parser = size(input_string, 2) + 5;
        end
        
        % The SL sometimes puts '&#xd;' at the end, without further data
        % afterwards.... so check if there is another fieldname-value pair.
        if isempty(strfind(input_string(parser:end), ':'))
            parser = size(input_string, 2) + 1;
        end        
    end
end

