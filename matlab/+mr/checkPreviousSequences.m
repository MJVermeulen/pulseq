
function checkPreviousSequences(FileString,SequenceList)
%This function takes in a filestring and a text file with file names. It
%checks if the input FileString is on the filestring list. If it isn't it
%adds it to the text file and does nothing to the filestring. If it is it
%adds a _Vn to the file name. The n can be any number.If it finds a version
%that already existits it increases the version name until that version
%doesn't exist. 
createdSequences = SequenceList; % Output text file
creationDate = datestr(now, 'yyyy-mm-dd HH:MM:SS'); % Get current date and time
% Get the name of the currently running MATLAB script
stack = dbstack('-completenames');
if numel(stack) >= 2
    [scriptPath, scriptName, ~] = fileparts(stack(2).file);
else
    scriptPath = '';
    scriptName = 'base';
end
% Check if the file exists
if exist(createdSequences, 'file') == 2
    % Open the file in read mode
    fid = fopen(createdSequences, 'r');
    fileContents = fread(fid, '*char')'; % Read file content as a string
    fclose(fid); % Close file after reading
    
    % Split file content into lines
    fileLines = splitlines(string(fileContents));
    for i = 1:length(fileLines)
    words = split(fileLines(i)); % Split line into words
        if ~isempty(words)
            firstWords(i) = words(1); % Store first word
            %disp(words(1))
            %disp(firstWords)
        end
    end

    % Check if the text already exists and increment version number if necessary
    newText = FileString;
    version = 2;
    
    while any(strcmp(firstWords, newText)) % Keep increasing version until unique

        %disp(firstWords)
        %disp(version)
        newText = FileString + "_v" + version;
        version = version + 1;
        %disp(firstWords)
    end
    FileString = newText;
    % Open file in append mode and write the new text on a new line
    fid = fopen(createdSequences, 'a');
        fprintf(fid, '%s created using %s\n on %s\n\n', FileString, scriptName, creationDate);
    fclose(fid);
    fprintf('Written: "%s created using %s"\n', newText, scriptName);
else
    % If file doesn't exist, create it and add the header
    %creationDate = datestr(now, 'yyyy-mm-dd HH:MM:SS'); % Get current date and time
    fid = fopen(createdSequences, 'w');
    
    % Write header with script name and creation date
    fprintf(fid, 'All sequences created in %s\n This file was made in %s\n\n', creationDate,pwd);
    fprintf(fid, '%s created using %s\n on %s\n\n', FileString, scriptName, creationDate); % Write first entry
    
    fclose(fid);
    fprintf('The file "%s" has been created with a header, and text has been written.\n', createdSequences);
end
end