function eyehplfp(varargin)

%startup

% get channel string
[p1, chstr] = nptFileParts(pwd);
% get array string
[p2, arrstr] = nptFileParts(p1);
% get session string
[p3, sesstr] = nptFileParts(p2);
% get day string
[p4, daystr] = nptFileParts(p3);

disp(p1)
disp(p2)

if ~isdeployed
    addpath('~/matlab/DPV')
    addpath('~/matlab/newNpt')
    addpath('~/matlab/Hippocampus')
    addpath('~/matlab/neuroshare')
    addpath('~/hmmsort')
end

% to read Args
load([p2,'/rsData']);

rh = rplhighpass('auto','SaveLevels',2,varargin{:});
rl = rpllfp('auto','SaveLevels',2,varargin{:});

figure
rh = plot(rplhighpass('auto','redo','HighpassFreqs',[500 10000]),1,'FFT');
saveas(gcf,'hp.fig');
saveas(gcf,'hp.png');
close

figure
rl = plot(rpllfp('auto'),1,'FFT');
saveas(gcf,'lfp.fig');
saveas(gcf,'lfp.png');
close

if(isempty(strfind(sesstr,'test')))
    if(~Args.SkipSort)
        display('Launching spike sorting ...')
        % check to see if we should sort this channel
        if(isempty(dir('skipsort.txt')))
            
            % make channel direcory on HPC, copy to HPC, cd to channel directory, and then run hmmsort
            display('Creating channel directory ...')
            if ~Args.UseHPC
                syscmd = ['ssh eleys@atlas7; cd ~/hpctmp/Data/' daystr '/' sesstr '/' arrstr '; mkdir ' chstr];
                display(syscmd)
                system(syscmd);
                display('Transferring rplhighpass file ...')
                syscmd = ['scp rplhighpass.mat eleys@atlas7:~/hpctmp/Data/' daystr '/' sesstr '/' arrstr '/' chstr];
                display(syscmd)
                rval=1;
                while(rval~=0)
                    rval=system(syscmd);
                end
                syscmd = ['cd ~/hpctmp/Data/' daystr '/' sesstr '/' arrstr '/' chstr];
            end
            display('Running spike sorting ...')
            syscmd = '~/hmmsort/hmmsort_pbs.py ~/hmmsort';
            display(syscmd)
            [~,decodejobid] = system(syscmd);
            
            % create transfer job
            fid = fopen('transfer_job0000.pbs','w');
            fprintf(fid,...
                ['#!/bin/bash\n'...
                '#PBS -q serial\n'...
                '#PBS -W depend=afterok:',decodejobid,'\n'...
                'cd "$PBS_O_WORKDIR"\n'...
                'cwd=$PWD\n'...
                'channelStr=${cwd:`expr index "$cwd" 2018`-1}\n'...
                'targetDir=''/volume1/Hippocampus/Data/picasso/''\n'...
                'targetDir+=$channelStr\n'...
                'ssh -p 8398 hippocampus@cortex.nus.edu.sg mkdir -p $targetDir\n'...
                'scp -P 8398 -r ./* hippocampus@cortex.nus.edu.sg:$targetDir &&\n'...
                'rm -rv *&&\n'...
                'touch transferred.txt']);
            fclose(fid);
            
            % submit transfer job
            system('source ~/.bash_profile; source /etc/profile.d/rec_modules.sh; module load pbs; qsub transfer_job0000.pbs');
            
        end  % if(isempty(dir('skipsort.txt')))
    end  % if(Args.SkipSort)
else
system('transfersession.sh');
fid = fopen('transferred.txt','w');
fclose(fid);
end
