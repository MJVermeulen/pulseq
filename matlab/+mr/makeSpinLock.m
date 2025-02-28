function [SL] = makeSpinLock(tSL,fSL,SL_phs,system) 

    Nringdown = round(system.rfRingdownTime/system.rfRasterTime);
    N         = round(tSL/system.rfRasterTime) + Nringdown;
    t         = (1:N)' * system.rfRasterTime;
    signal    = ones(N,1) * fSL;
    if Nringdown>0
        signal(end-Nringdown+1:end,1) = 0.0;    
    end
    SL.type         = 'rf';
    SL.t            = t;
    SL.signal       = signal;
    SL.freqOffset   = 0;
    SL.phaseOffset  = SL_phs;
    SL.deadTime     = system.rfDeadTime;
    SL.ringdownTime = system.rfRingdownTime;
    SL.delay        = system.rfDeadTime;
    SL.shape_dur    = SL.t(end);
    SL.use          = 'preparation';

    clear Nringdown N t signal;

end