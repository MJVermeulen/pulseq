function [rf, delay] = makeBlockPulse(flip,varargin)
%makeBlockPulse Create a block pulse with optional slice selectiveness.
%   rf=makeBlockPulse(flip, 'Duration', dur) Create block pulse
%   with given flip angle and duration.
%
%   rf=makeBlockPulse(flip, 'Bandwidth', bw) Create block pulse
%   with given flip angle and bandwidth (Hz). The duration is calculated as
%   1/(4*bw)
%
%   rf=makeBlockPulse(..., 'freqOffset', f,'phaseOffset',p)
%   Create block pulse with frequency offset and phase offset.
%
%   rf=makeBlockPulse(..., 'ppmOffset')
%   Create block RF pulse with frequency offset specified in PPM (e.g.
%   actual frequency offset proportional to the true Larmor frequency); can
%   be combined with the 'freqOffset' specified in Hz.
%
%   [rf, delay]=makeBlockPulse(...) returns the corresponding delay object 
%   that takes care of the RF ringdown time.
%
%   See also  Sequence.addBlock

validPulseUses = mr.getSupportedRfUse();

persistent parser
if isempty(parser)
    parser = inputParser;
    parser.FunctionName = 'makeBlockPulse';
    
    % RF params
    addRequired(parser, 'flipAngle', @isnumeric);
    addOptional(parser, 'system', [], @isstruct); % for slice grad
    addParamValue(parser, 'duration', 0, @isnumeric);
    addParamValue(parser, 'freqOffset', 0, @isnumeric);
    addParamValue(parser, 'phaseOffset', 0, @isnumeric);
    addParamValue(parser, 'freqPPM', 0, @isnumeric);
    addParamValue(parser, 'phasePPM', 0, @isnumeric);
    addParamValue(parser, 'timeBwProduct', 0, @isnumeric);
    addParamValue(parser, 'bandwidth', 0, @isnumeric);
    % Slice params
    addParamValue(parser, 'maxGrad', 0, @isnumeric);
    addParamValue(parser, 'maxSlew', 0, @isnumeric);
    addParamValue(parser, 'sliceThickness', 0, @isnumeric);
    % Delay
    addParamValue(parser, 'delay', 0, @isnumeric);
    % whether it is a refocusing pulse (for k-space calculation)
    addParamValue(parser, 'use', 'u', @(x) any(validatestring(x,validPulseUses)));
end
parse(parser, flip, varargin{:});
opt = parser.Results;

if isempty(opt.system)
    system=mr.opts();
else
    system=opt.system;
end

if opt.duration == 0
    if opt.timeBwProduct > 0
        opt.duration = opt.timeBwProduct/opt.bandwidth;
    elseif opt.bandwidth > 0
        opt.duration = 1/(4*opt.bandwidth);
    else
        error('Either bandwidth or duration must be defined');
    end
end

BW = 1/(4*opt.duration);
N = round(opt.duration/system.rfRasterTime);
t = [0; N]*system.rfRasterTime; % CHECKME whether we start at 0 or at 0.5 or at 1 
signal = opt.flipAngle/(2*pi)/opt.duration*ones(size(t));

rf.type = 'rf';
rf.signal = signal;
rf.t = t;
rf.shape_dur=t(end);
rf.freqOffset = opt.freqOffset;
rf.phaseOffset = opt.phaseOffset;
rf.freqPPM = opt.freqPPM;
rf.phasePPM = opt.phasePPM;
rf.deadTime = system.rfDeadTime;
rf.ringdownTime = system.rfRingdownTime;
rf.delay = opt.delay;
rf.center = rf.shape_dur/2;
if ~isempty(opt.use)
    rf.use=opt.use;
end
if rf.deadTime > rf.delay
    rf.delay = rf.deadTime;
end

% v1.4 finally eliminates RF zerofilling
% if rf.ringdownTime > 0
%     tFill = (1:round(rf.ringdownTime/1e-6))*1e-6;  % Round to microsecond
%     rf.t = [rf.t rf.t(end)+tFill];
%     rf.signal = [rf.signal, zeros(size(tFill))];
% end
if rf.ringdownTime > 0 && nargout > 1
    delay=mr.makeDelay(mr.calcDuration(rf)+rf.ringdownTime);
end

% RF amplitude check
rf_amplitude=max(abs(rf.signal));
if rf_amplitude>system.maxB1
    warning('WARNING: system maximum RF amplitude exceeded (%.01f%%)', rf_amplitude/system.maxB1*100);
end
