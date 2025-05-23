function [rf, gz, gzr, delay] = makeArbitraryRf(signal,flip,varargin)
%makeArbitraryRf Create an RF pulse with the given pulse shape.
%   rf=makeArbitraryRf(singal, flip) Create RF pulse with complex signal 
%   and given flip angle (in radians)
%
%   rf=makeArbitraryRf(..., 'freqOffset', f,'phaseOffset',p)
%   Create arbitrary RF pulse with frequency offset and phase offset.
%
%   rf=makeArbitraryRf(..., 'ppmOffset')
%   Create arbitrary RF pulse with frequency offset specified in PPM (e.g.
%   actual frequency offset proportional to the true Larmor frequency); can
%   be combined with the 'freqOffset' specified in Hz.
%
%   [rf, gz]=makeArbitraryRf(..., 'Bandwidth', bw, 'SliceThickness', st) 
%   Create RF pulse and corresponding slice select gradient. The bandwidth
%   of the pulse must be given for the specified shape.
%
%   See also  Sequence.makeSincPulse, Sequence.addBlock

validPulseUses = mr.getSupportedRfUse();

persistent parser
if isempty(parser)
    parser = inputParser;
    parser.FunctionName = 'makeArbitraryRf';
    
    % RF params
    addRequired(parser, 'signal', @isnumeric);
    addRequired(parser, 'flipAngle', @isnumeric);
    addOptional(parser, 'system', [], @isstruct);
    addParamValue(parser, 'freqOffset', 0, @isnumeric);
    addParamValue(parser, 'phaseOffset', 0, @isnumeric);
    addParamValue(parser, 'freqPPM', 0, @isnumeric);
    addParamValue(parser, 'phasePPM', 0, @isnumeric);
    addParamValue(parser, 'timeBwProduct', 0, @isnumeric);
    addParamValue(parser, 'bandwidth', 0, @isnumeric);
    addParamValue(parser, 'center', NaN, @isnumeric);
    % Slice params
    addParamValue(parser, 'maxGrad', 0, @isnumeric);
    addParamValue(parser, 'maxSlew', 0, @isnumeric);
    addParamValue(parser, 'sliceThickness', 0, @isnumeric);
    % Delay
    addParamValue(parser, 'delay', 0, @isnumeric);
    addParamValue(parser, 'dwell', 0, @isnumeric); % dummy default value
    % whether it is a refocusing pulse (for k-space calculation)
    addParamValue(parser, 'use', 'u', @(x) any(validatestring(x,validPulseUses)));
end
parse(parser, signal, flip,varargin{:});
opt = parser.Results;

if isempty(opt.system)
    system=mr.opts();
else
    system=opt.system;
end

if opt.dwell==0
    opt.dwell=system.rfRasterTime;
end

signal = signal./abs(sum(signal.*opt.dwell))*flip/(2*pi);

if size(signal,1)>size(signal,2)
    signal=signal.';
end

N=  length(signal);
duration = N*opt.dwell;
t = ((1:N)'-0.5)*opt.dwell;

rf.type = 'rf';
rf.signal = signal(:);
rf.t = t;
rf.shape_dur=duration;
rf.freqOffset = opt.freqOffset;
rf.phaseOffset = opt.phaseOffset;
rf.freqPPM = opt.freqPPM;
rf.phasePPM = opt.phasePPM;
rf.deadTime = system.rfDeadTime;
rf.ringdownTime = system.rfRingdownTime;
rf.delay = opt.delay;
if ~isempty(opt.use)
    rf.use=opt.use;
end
if rf.deadTime > rf.delay
    rf.delay = rf.deadTime;
end

if isfinite(opt.center)
    rf.center=opt.center;
    if rf.center < 0, rf.center = 0; end
    if rf.center > rf.shape_dur, rf.center = rf.shape_dur; end
else
    rf.center = mr.calcRfCenter(rf);
end

if opt.timeBwProduct>0
    if opt.bandwidth > 0
        error('Both ''bandwidth'' and ''timeBwProduct'' cannot be specified at the same time');
    else
        opt.bandwidth=opt.timeBwProduct/duration; % QL
    end
end

if nargout>1
    assert(opt.sliceThickness > 0, 'SliceThickness must be provided');
    assert(opt.bandwidth > 0, 'Bandwidth of pulse must be provided');
    warning('FIXME: there are some potential issues with the bandwidth and related parameters, double check (e-mail communication)');
    if opt.maxGrad > 0
        system.maxGrad = opt.maxGrad;
    end
    if opt.maxSlew > 0
        system.maxSlew = opt.maxSlew;
    end
    
    BW = opt.bandwidth;
    if opt.timeBwProduct > 0
        BW = opt.timeBwProduct/duration;
    end

    amplitude = BW/opt.sliceThickness;
    area = amplitude*duration;
    gz = mr.makeTrapezoid('z', system, 'flatTime', duration, ...
                          'flatArea', area);
    
    if rf.delay > gz.riseTime
        gz.delay = ceil((rf.delay - gz.riseTime)/system.gradRasterTime)*system.gradRasterTime; % round-up to gradient raster
    end
    if rf.delay < (gz.riseTime+gz.delay)
        rf.delay = gz.riseTime+gz.delay; % these are on the grad raster already which is coarser 
    end
    
    if nargout > 2
        gzr= mr.makeTrapezoid('z', system, 'Area', -area*(1-rf.center)/rf.shape_dur-0.5*(gz.area-area));
    end
end

% v1.4 finally eliminates RF zerofilling
% if rf.ringdownTime > 0
%     tFill = (1:round(rf.ringdownTime/1e-6))*1e-6;  % Round to microsecond
%     rf.t = [rf.t rf.t(end)+tFill];
%     rf.signal = [rf.signal, zeros(size(tFill))];
% end
if rf.ringdownTime > 0 && nargout > 3
    delay=mr.makeDelay(mr.calcDuration(rf)+rf.ringdownTime);
end

% RF amplitude check
rf_amplitude=max(abs(rf.signal));
if rf_amplitude>system.maxB1
    warning('WARNING: system maximum RF amplitude exceeded (%.01f%%)', rf_amplitude/system.maxB1*100);
end

end
