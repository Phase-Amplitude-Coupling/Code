function DEM_coupled_oscillators
% Dual estimation of the Lorenz system: Cross-validation of Laplace schemes
%__________________________________________________________________________
% This routine illustrates the inversion of a loosely coupled oscillator
% model using generalised filtering. In this example, three regions are
% coupled in terms of their amplitude and phase in a hierarchical fashion.
% Data are generated under a particular set of parameters. The timeseries
% are then transformed using a Hilbert transform into the corresponding
% analytic signal. This then constitutes the data feature for subsequent
% inversion using generalised filtering; here, in four generalised
% coordinates of motion. By assuming fairly precise priors on the amplitude
% of random fluctuations one can recover the parameters and use the
% posterior density for subsequent Bayesian model comparison. In this
% example, we used Bayesian model reduction to assess the evidence for
% models with and without amplitude or phase coupling.
%
% The parameters and orders of this example have been optimised to provide
% proof of principle this sort of model can be inverted using generalised
% filtering.  The sensitivity to these parameters and orders can be
% assessed numerically by editing the code.
%__________________________________________________________________________
% Copyright (C) 2008 Wellcome Trust Centre for Neuroimaging

% Karl Friston
% $Id: DEM_coupled_oscillators.m 7324 2018-06-02 12:12:20Z karl $

% specify states and parameters
%==========================================================================
N     = 128;                            % number of time points
n     = 3;                          	% number of sources (oscillators)
Hz    = 8;                           	% characteristic frequency (Hz)
dt    = 1/64;                        	% sampling interval (sec)

% model states (where hidden states comprise phase differences)
%--------------------------------------------------------------------------
x.r   = ones(n,1)*(1/16);           	% amplitude
x.p   = ones(n,1)*(1/16);             	% phase  differences
x.w   = ones(1,1)*(1/16);              	% phase (common to sources)

% model parameters
%--------------------------------------------------------------------------
P.L   = diag(ones(n,1));             	% lead field (measurement mapping)

% full
P.Ap = [log(1/8) log(1/8) log(1/32) log(1/32)];     % amplitude coupling
P.Ar = [log(1/4) log(1/4) log(1/16) log(1/16)];     % phase coupling

% phase only
% P.Ap = [log(1/16) log(1/16) log(1/32) log(1/32)];   % amplitude coupling
% P.Ar = [log(1/4) log(1/4) log(1/16) log(1/16)];     % phase coupling

P.C   = sparse(1,1,1,n,1)/8;         	% exogenous input to first source
P.r   = 1/8;                           	% weak amplitude
P.w   = 2*pi*Hz*dt;                   	% intrinsic frequency

% observation function (to generate timeseries)
%--------------------------------------------------------------------------
g = @(x,v,P) P.L*((x.r).*cos(x.p + x.w));

% equations of motion (simplified coupled oscillator model)
%--------------------------------------------------------------------------
f = @(x,v,P) [([-1/16,-exp(P.Ap(3)),0;exp(P.Ap(1)),-1/16,-exp(P.Ap(4));...
    0,exp(P.Ap(2)),-1/16]).*cos(bsxfun(@minus,x.p,x.p'))*(x.r - P.r)...
    + P.C*v.*cos(x.p);
    sum(([0,exp(P.Ar(3)),0;exp(P.Ar(1)),0,exp(P.Ar(4));...
    0,exp(P.Ar(2)),0]).*exp(-abs(bsxfun(@minus,x.r,x.r'))).*...
    sin(bsxfun(@minus,x.p,x.p')),2)-((P.C*v.*sin(x.p))./x.r);
    P.w];

% causes or exogenous input (a Gaussian function of peristimulus time)
%--------------------------------------------------------------------------
U = exp(-((1:N) - N/2).^2/((N/8)^2)); 	% exogenous input
T = (1:N)*dt;                        	% sample times (seconds)

% parameters for generalised filtering (see spm_LAP)
%--------------------------------------------------------------------------
E.n     = 4;                          	% embedding dimension          
E.d     = 1;                           	% data embedding 
E.nN    = 8;                         	% number of iterations
E.s     = 1/2;                      	% smoothness of fluctuations

% first level state space model
%--------------------------------------------------------------------------
M(1).E  = E;                        	% filtering parameters
M(1).x  = x;                            % initial states 
M(1).f  = f;                        	% equations of motion
M(1).g  = g;                         	% observation mapping
M(1).pE = P;                          	% model parameters
M(1).V  = exp(12);                    	% precision of observation noise
M(1).W  = exp(12);                    	% precision of state noise

% second level � causes or exogenous forcing term
%--------------------------------------------------------------------------
M(2).v  = 0;                          	% initial causes
M(2).V  = exp(16);                    	% precision of exogenous causes

% create data with known parameters (P)
%==========================================================================
DEM = spm_DEM_generate(M,U,P);

% transform analytic signal to create a new data feature
%==========================================================================

% analytic signal (via Hilbert transform)
%--------------------------------------------------------------------------
Y  = spm_hilbert(full(DEM.Y)');       	% analytic signal
Yr = abs(Y)';                         	% amplitude
Yp = unwrap(angle(Y));               	% phase
Yp = Yp' - ones(n,1)*(1:N)*P.w;       	% phase difference
Y  = [Yr; Yp];                        	% analytic data feature

% show synthetic data,latent states and exogenous input
%--------------------------------------------------------------------------
spm_figure('GetWin','synthetic data');
spm_DEM_qU(DEM.pU);

subplot(4,2,2), plot(T,DEM.pU.x{1}(1:n,:)')
title('hidden amplitude','FontSize',16)
xlabel('time (seconds)'), spm_axis tight, box off

subplot(4,2,4), plot(T,DEM.pU.x{1}((1:n) + n,:)')
title('phase difference','FontSize',16)
xlabel('time (seconds)'), spm_axis tight, box off

subplot(4,2,6), plot(T,Yr)
title('response amplitude','FontSize',16)
xlabel('time (seconds)'), spm_axis tight, box off

subplot(4,2,8), plot(T,Yp)
title('unwrapped phase','FontSize',16)
xlabel('time (seconds)'), spm_axis tight, box off
drawnow

% Now try to recover model parameters from data features
%==========================================================================

% change observation function (g) to generate analytic signal
%--------------------------------------------------------------------------
g = @(x,v,P) [P.L*x.r; x.p];

% initialization of priors over parameters
%--------------------------------------------------------------------------
pE       = P;                         	% prior parameters
pC       = spm_zeros(P);               	% prior variance 

pE.Ar    = [-3 -3 -3 -3]; 
pE.Ap    = [-3 -3 -3 -3]; 

pC.Ar    = (P.Ar ~= 0);               	% and set the prior variance to 1
pC.Ap    = (P.Ap ~= 0);

Vr       = ones(1,n)*5;                	% log precision of sampling noise
Vp       = ones(1,n)*5;               	% and state noise

% place new observation function and priors in generative model
%--------------------------------------------------------------------------
DEM.M(1).g  = g;
DEM.M(1).pE = pE;
DEM.M(1).pC = diag(spm_vec(pC))*(1/1);
DEM.M(1).V  = exp([Vr Vp]);   
DEM.M(1).W  = exp([Vr Vp 32]);       	% use precise beliefs about time

% data and known input; removing initial time points to suppress artefacts
%--------------------------------------------------------------------------
DEM.Y = Y(:,8:end-8);
DEM.U = U(:,8:end-8);
  
% Inversion using generalised filtering 
%==========================================================================
LAP   = spm_DEM(DEM);

% Show parameters
%--------------------------------------------------------------------------
spm_figure('GetWin','Parameters'); clf; spm_DEM_qP(LAP.qP,LAP.pP)
subplot(2,1,1),legend('mean','90% CI','Location','North'); 
legend(gca,'boxoff')
title('Estimated and true (black) parameters','FontSize',16)

% use Bayesian model reduction to test different hypotheses
%==========================================================================
model{1} = 'no coupling';
model{2} = 'no amplitude coupling';
model{3} = 'no phase coupling';
model{4} = 'Full model';

% apply precise shrinkage priors to off-diagonal coupling elements
%--------------------------------------------------------------------------
PC{1} = pC; PC{1}.Ar = zeros(1,4); PC{1}.Ap = zeros(1,4);
PC{2} = pC; PC{2}.Ap = zeros(1,4);
PC{3} = pC; PC{3}.Ar = zeros(1,4);
PC{4} = pC;

%  evaluate the evidence for these new models or prior constraints
%--------------------------------------------------------------------------
qE    = LAP.qP.P{1};
qC    = LAP.qP.C;
pE    = LAP.M(1).pE;
pC    = LAP.M(1).pC;
for m = 1:numel(PC)
    rC     = diag(spm_vec(PC{m}));
    F(m,1) = spm_log_evidence(qE,qC,pE,pC,pE,rC);
end

% report marginal log likelihood or evidence
%--------------------------------------------------------------------------
F = F - min(F);

spm_figure('GetWin','Model Comparison');clf;
subplot(2,2,1), bar(F,'c')
title('Log evidence','FontSize',16)
xlabel(model), axis square, box off

subplot(2,2,2), bar(spm_softmax(F(:)),'c')
title('Probability','FontSize',16)
xlabel(model), axis square, box off
