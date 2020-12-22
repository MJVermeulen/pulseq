function read(obj,filename,varargin)
%READ Load sequence from file.
%   READ(seqObj, filename, ...) Read the given filename and load sequence
%   data into sequence object.
%
%   optional parwameter 'detectRFuse' can be given to let the function
%   infer the currently missing flags concerning the intended use of the RF
%   pulses (excitation, refocusing, etc). These are important for the
%   k-space trajectory calculation
%
%   Examples:
%   Load the sequence defined in gre.seq in my_sequences directory
%
%       read(seqObj,'my_sequences/gre.seq')
%
% See also  write

detectRFuse=false;
if ~isempty(varargin) && ~isempty(strfind(varargin{:},'detectRFuse'))
    detectRFuse=true;
end

fid = fopen(filename);

% Clear sequence data
%obj.blockEvents = [];
obj.blockEvents = {};
obj.definitions = containers.Map();
obj.gradLibrary = mr.EventLibrary();
obj.shapeLibrary = mr.EventLibrary();
obj.rfLibrary = mr.EventLibrary();
obj.adcLibrary = mr.EventLibrary();
obj.delayLibrary = mr.EventLibrary();
obj.trigLibrary = mr.EventLibrary();
obj.labelsetLibrary = mr.EventLibrary();
obj.labelincLibrary = mr.EventLibrary();
obj.extensionStringIDs={};
obj.extensionNumericIDs=[];

% Load data from file
while true
    section = skipComments(fid);
    if section == -1
        break
    end
    
    switch section
        case '[DEFINITIONS]'
            obj.definitions = readDefinitions(fid);
        case '[VERSION]'
            [version_major, ...
             version_minor, ...
             version_revision] = readVersion(fid);
            assert(version_major == obj.version_major, ...
                'Unsupported version_major %d', version_major)
            %
            if version_major==1 && version_minor==2 && obj.version_major==1 && obj.version_minor==3
                compatibility_mode_12x_13x=true;
            else
                compatibility_mode_12x_13x=false;
                %
                assert(version_minor == obj.version_minor, ...
                    'Unsupported version_minor %d', version_minor)
                % MZ: I think we should tolerate minor revision changes
                %assert(version_revision == obj.version_revision, ...
                %    'Unsupported version_revision %d', version_revision)
                assert(version_revision <= obj.version_revision, ... % MZ: accept loading older files
                    'Unsupported version_revision %d', version_revision)
            end
            if (~compatibility_mode_12x_13x)
                obj.version_major = version_major;
                obj.version_minor = version_minor;
                obj.version_revision = version_revision;
            end
        case '[BLOCKS]'
            if ~exist('version_major')
                error('Pulseq file has to include [VERSION] section prior to [BLOCKS] section');
            end
            obj.blockEvents = readBlocks(fid, compatibility_mode_12x_13x);
        case '[RF]'
            obj.rfLibrary = readEvents(fid, [1 1 1 1e-6 1 1]);
        case '[GRADIENTS]'
            obj.gradLibrary = readEvents(fid, [1 1 1e-6], 'g' ,obj.gradLibrary);
        case '[TRAP]'
            obj.gradLibrary = readEvents(fid, [1 1e-6 1e-6 1e-6 1e-6], 't', obj.gradLibrary);
        case '[ADC]'
            obj.adcLibrary = readEvents(fid, [1 1e-9 1e-6 1 1]);
        case '[DELAYS]'
            obj.delayLibrary = readEvents(fid, 1e-6);
        case '[SHAPES]'
            obj.shapeLibrary = readShapes(fid);
        case '[EXTENSIONS]'
            obj.extensionLibrary = readEvents(fid);
        otherwise
            if     strncmp('extension TRIGGERS', section, 18) 
                id=str2num(section(19:end));
                obj.setExtensionStringAndID('TRIGGERS',id);
                obj.trigLibrary = readEvents(fid, [1 1 1e-6 1e-6]);
            elseif strncmp('extension LABELSET', section, 18) 
                id=str2num(section(19:end));
                obj.setExtensionStringAndID('LABELSET',id);
                obj.labelsetLibrary = readAndParseEvents(fid,@str2num,@(s)find(strcmp(mr.getSupportedLabels,s)));
            elseif strncmp('extension LABELINC', section, 18) 
                id=str2num(section(19:end));
                obj.setExtensionStringAndID('LABELINC',id);
                obj.labelincLibrary = readAndParseEvents(fid,@str2num,@(s)find(strcmp(mr.getSupportedLabels,s)));
            else
                error('Unknown section code: %s', section);
            end
    end
end
fclose(fid);

obj.blockDurations=zeros(1,length(obj.blockEvents));
gradChannels={'gx','gy','gz'};
gradPrevLast=zeros(1,length(gradChannels));
for iB = 1:length(obj.blockEvents)
    b=obj.getBlock(iB);
    block_duration=mr.calcDuration(b);
    obj.blockDurations(iB)=block_duration;
    % we also need to keep track of the event IDs because some Pulseq files written by external software may contain repeated entries so searching by content will fail 
    eventIDs=obj.blockEvents{iB};
    % update the objects by filling in the fields not contained in the
    % pulseq file
    for j=1:length(gradChannels)
        grad=b.(gradChannels{j});
        if isempty(grad)
            gradPrevLast(j)=0;
            continue;
        end
        if strcmp(grad.type,'grad')
            if grad.delay>0 
                gradPrevLast(j)=0;
            end
            if isfield(grad,'first')
                continue;
            end
            grad.first = gradPrevLast(j);
            % restore samples on the edges of the gradient raster intervals
            % for that we need the first sample
            odd_step1=[grad.first 2*grad.waveform'];
            odd_step2=odd_step1.*(mod(1:length(odd_step1),2)*2-1);
            waveform_odd_rest=(cumsum(odd_step2).*(mod(1:length(odd_step2),2)*2-1))';
            grad.last = waveform_odd_rest(end);
            gradPrevLast(j) = grad.last;
            
            if grad.delay+length(grad.waveform)*obj.gradRasterTime+eps<block_duration
                gradPrevLast(j)=0;
            end
            %b.(gradChannels{j})=grad;
            % update library object
            amplitude = max(abs(grad.waveform));
            old_data = [amplitude grad.shape_id grad.delay];
            new_data = [amplitude grad.shape_id grad.delay grad.first grad.last];
            id=eventIDs(j+2);
            update_data(obj.gradLibrary, id, old_data, new_data,'g');
        else
            gradPrevLast(j)=0;
        end
    end
    %% copy updated objects back into the event library
    %obj.setBlock(iB,b);
    
    
%for iB=1:size(obj.blockEvents,1)
%     % update the objects by filling in the fields not contained in the
%     % pulseq file
%     for j=1:length(gradChannels)
%         grad=b.(gradChannels{j});
%         if isempty(grad)
%             continue;
%         end
%         if strcmp(grad.type,'grad')
%             grad.first = grad.waveform(1); % MZ: eventually we should use extrapolation by 1/2 gradient rasters here
%             grad.last = grad.waveform(end);
%             b.(gradChannels{j})=grad;
%         end;
%     end
%     % copy updated objects back into the event library
%     obj.setBlock(iB,b);
end

if detectRFuse
    % find the RF pulses, list flip angles
    % and work around the current (rev 1.2.0) Pulseq file format limitation
    % that the RF pulse use is not stored in the file
    for k=obj.rfLibrary.keys
        libData=obj.rfLibrary.data(k).array;
        rf=obj.rfFromLibData(libData);
        flipAngleDeg=abs(sum(rf.signal))*rf.t(1)*360; %we use rfex.t(1) in place of opt.system.rfRasterTime
        % fix libData
        if length(libData) < 9
            if flipAngleDeg < 90.01 % we add 0.01 degree to account for rounding errors which we've experienced for very short RF pulses
                libData(9) = 0; % or 1 ?
            else
                libData(9) = 2; % or 1 ?
            end
            obj.rfLibrary.data(k).array=libData;
        end
    end
end

return

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%% Helper functions  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    function def = readDefinitions(fid)
        %readDefinitions Read the [DEFINITIONS] section of a sequence file.
        %   defs=readDefinitions(fid) Read user definitions from file
        %   identifier of an open MR sequence file and return a map of
        %   key/value entries.
        
        def = containers.Map;
        line = strip(fgetl(fid));
        while ischar(line) && ~(isempty(line) || line(1) == '#')
            tok = textscan(line, '%s');
            def(tok{1}{1}) = str2double(tok{1}(2:end));
            if ~all(isfinite(def(tok{1}{1})))
                def(tok{1}{1}) = line((length(tok{1}{1})+2):end);
            end
            line = fgetl(fid);
        end
    end    

    function [major, minor, revision] = readVersion(fid)
        %readVersion Read the [VERSION] section of a sequence file.
        %   defs=readVersion(fid) Read Pulseq version from file
        %   identifier of an open MR sequence file and return it
        
        major = [];
        minor = [];
        revision = [];
        line = fgetl(fid);
        while ischar(line) && ~(isempty(line) || line(1)=='#')
            tok = textscan(line,'%s');
            switch tok{1}{1}
                case 'major'
                    major = str2double(tok{1}(2:end));
                case 'minor'
                    minor = str2double(tok{1}(2:end));
                case 'revision'
                    revision = str2double(tok{1}(2:end));
            end
            line = fgetl(fid);
        end
    end

    function eventTable = readBlocks(fid, compatibility_mode_12x_13x)
        %readBlocks Read the [BLOCKS] section of a sequence file.
        %   library=readBlocks(fid) Read blocks from file identifier of an
        %   open MR sequence file and return the event table.
        
        eventTable = {};
        line = fgetl(fid);
        while ischar(line) && ~(isempty(line) || line(1) == '#')
            blockEvents = sscanf(line, '%f')';
            %eventTable = [eventTable; blockEvents(2:end)];
            if (compatibility_mode_12x_13x)
                eventTable{blockEvents(1)} = [blockEvents(2:end) 0];
            else
                eventTable{blockEvents(1)} = blockEvents(2:end);
            end
            line = fgetl(fid);
        end
    end

    function eventLibrary = readEvents(fid, scale, type, eventLibrary)
        %readEvents Read an event section of a sequence file.
        %   library=readEvents(fid) Read event data from file identifier of
        %   an open MR sequence file and return a library of events.
        %
        %   library=readEvents(fid,scale) Read event data and scale
        %   elements according to column vector scale.
        %
        %   library=readEvents(fid,scale,type) Attach the type string to
        %   elements of the library.
        %
        %   library=readEvents(...,library) Append new events to the given
        %   library.
        if nargin < 2
            scale = 1;
        end
        if nargin < 4
            eventLibrary = mr.EventLibrary();
        end
        line = fgetl(fid);
        while ischar(line) && ~(isempty(line) || line(1) == '#')
            data = sscanf(line,'%f')';
            id = data(1);
            data = scale.*data(2:end);
            if nargin < 3
                eventLibrary.insert(id, data);
            else
                eventLibrary.insert(id, data, type);
            end
            
            line=fgetl(fid);
        end
    end

    function eventLibrary = readAndParseEvents(fid, varargin)
        %readAndParseEvents Read an event section of a sequence file.
        %   library=readAndParseEvents(fid) Read event data from file 
        %   identifier of an open MR sequence file and return a library of 
        %   events.
        %
        %   library=readAndParseEvents(fid,parser1,parser2,...) Read event  
        %   data and convert the elements using to the provided parser. 
        %   Default parser is str2num()
        %
        eventLibrary = mr.EventLibrary();
        line = fgetl(fid);
        while ischar(line) && ~(isempty(line) || line(1) == '#')
            datas=regexp(line, '(\s+)','split');
            data=zeros(1,length(datas)-1);
            id = str2num(datas{1});
            for i=2:length(datas)
                if i>nargin
                    data(i-1) = str2num(datas{i});
                else
                    data(i-1) = varargin{i-1}(datas{i});
                end
            end
            eventLibrary.insert(id, data);

            line=fgetl(fid);
        end
    end

    function shapeLibrary = readShapes(fid)
        %readShapes Read the [SHAPES] section of a sequence file.
        %   library=readShapes(fid) Read shapes from file identifier of an
        %   open MR sequence file and return a library of shapes.

        shapeLibrary = mr.EventLibrary();
        line = skipComments(fid);
        while ~(~ischar(line) || isempty(line) || ~strcmp(line(1:8), 'shape_id'))
            tok = textscan(line, '%s');
            id = str2double(tok{1}(2));
            line = skipComments(fid);
            tok = textscan(line, '%s');
            num_samples = str2double(tok{1}(2));
            data = [];
            line = skipComments(fid);   % first sample
            while ischar(line) && ~(isempty(line) || line(1) == '#')
                %data = [data sscanf(line, '%f')];
                data = [data single(sscanf(line, '%f'))]; % C-code uses single precision and we had problems already due to the rounding during reading in of the shapes...
                line = fgetl(fid);
            end
            line = skipComments(fid); % MZ: this is actually a bug forcing readShapes to read into the next section --> for nuw we just require [shapes] to be the last one...
            data = [num_samples data];
            shapeLibrary.insert(id, data);
        end
    end

    function nextLine = skipComments(fid)
        %skipComments Read lines of skipping blank lines and comments.
        %   line=skipComments(fid) Read lines from valid file identifer and
        %   return the next non-comment line.
        
        line = fgetl(fid);
        while ischar(line) && (isempty(line) || line(1) == '#')
            line = fgetl(fid);
        end
        if ischar(line)
            nextLine = line;
        else
            nextLine = -1;
        end
    end
end
