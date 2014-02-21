%CODEGENERATION.GENMEXINERTIA Generate MEX-function for robot inertia matrix
%
% cGen.genmexinertia() generates robot-specific MEX-functions to compute
% robot inertia matrix.
%
% Notes::
% - Is called by CodeGenerator.geninertia if cGen has active flag genmex
% - The inertia matrix is stored row by row to avoid memory issues.
% - The generated M-function recombines the individual MEX-functions for each row.
% - Access to generated functions is provided via subclass of SerialLink
%   whose class definition is stored in cGen.robjpath.
%
% Author::
%  Joern Malzahn, (joern.malzahn@tu-dortmund.de)
%
% See also CodeGenerator.CodeGenerator, CodeGenerator.gencoriolis.

% Copyright (C) 2012-2014, by Joern Malzahn
%
% This file is part of The Robotics Toolbox for Matlab (RTB).
%
% RTB is free software: you can redistribute it and/or modify
% it under the terms of the GNU Lesser General Public License as published by
% the Free Software Foundation, either version 3 of the License, or
% (at your option) any later version.
%
% RTB is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU Lesser General Public License for more details.
%
% You should have received a copy of the GNU Leser General Public License
% along with RTB.  If not, see <http://www.gnu.org/licenses/>.
%
% http://www.petercorke.com
%
% The code generation module emerged during the work on a project funded by
% the German Research Foundation (DFG, BE1569/7-1). The authors gratefully
% acknowledge the financial support.

function [] = genmexinertia(CGen)

%% Individual inertia matrix rows
CGen.logmsg([datestr(now),'\tGenerating MEX-function for the robot inertia matrix row' ]);

Q = CGen.rob.gencoords;
nJoints = CGen.rob.n;

for kJoints = 1:nJoints
    CGen.logmsg(' %s ',num2str(kJoints));
    symname = ['inertia_row_',num2str(kJoints)];
    fname = fullfile(CGen.sympath,[symname,'.mat']);
    
    if exist(fname,'file')
        tmpStruct = load(fname);
    else
        error ('genmfuninertia:SymbolicsNotFound','Save symbolic expressions to disk first!')
    end
    
    funfilename = fullfile(CGen.robjpath,[symname,'.c']);
    
    hStruct = createHeaderStructRow(CGen.rob,kJoints,symname);   %generate header
    
    CGen.mexfunction(tmpStruct.(symname), ...
        'funfilename',funfilename,...
        'funname',[CGen.rob.name,'_',symname],...
        'vars',{Q},...
        'output',['I_row',num2str(kJoints)],...
        'header',hStruct);
    
end
CGen.logmsg('\t%s\n',' done!');

%% Full inertia matrix
CGen.logmsg([datestr(now),'\tGenerating full inertia matrix m-function']);

symname = 'inertia';
f = sym(zeros(nJoints)); % dummy symbolic expression
funfilename = fullfile(CGen.robjpath,[symname,'.c']);

funname = [CGen.rob.name,'_',symname];

hStruct = createHeaderStructFullInertia(CGen.rob,symname); % create header
hFString = CGen.constructheaderstringc(hStruct);

fid = fopen(funfilename,'w+');

% Insert description header
fprintf(fid,'%s\n',hFString);
% Includes
fprintf(fid,'%s\n%s\n\n',...
    '#include "mex.h"',...
    ['#include "',funname,'.h','"']);

% Generate the mex gateway routine
funstr = CGen.genmexgatewaystring(f,'funname',funname, 'vars',{Q});
fprintf(fid,'%s',sprintf(funstr));

fclose(fid);

%% Compile the MEX file
srcDir = fullfile(CGen.ccodepath,'src');
hdrDir = fullfile(CGen.ccodepath,'include');

cfilelist = fullfile(srcDir,[funname,'.c']);
for kJoints = 1:nJoints
    cfilelist = [cfilelist, ' ',fullfile(srcDir,[CGen.rob.name,'_inertia_row_',num2str(kJoints),'.c'])];
end

if CGen.verbose
    eval(['mex ',funfilename, ' ',cfilelist,' -I',hdrDir, ' -v -outdir ',CGen.robjpath]);   
else
    eval(['mex ',funfilename, ' ',cfilelist,' -I',hdrDir,' -outdir ',CGen.robjpath]);
end

CGen.logmsg('\t%s\n',' done!');
end

function hStruct = createHeaderStructRow(rob,curJointIdx,fName)
[~,hStruct.funName] = fileparts(fName);
hStruct.shortDescription = ['Computation of the robot specific inertia matrix row for corresponding to joint ', num2str(curJointIdx), ' of ',num2str(rob.n),'.'];
hStruct.calls = {['Irow = ',hStruct.funName,'(rob,q)'],...
    ['Irow = rob.',hStruct.funName,'(q)']};
hStruct.detailedDescription = {'Given a full set of joint variables this function computes the',...
    ['inertia matrix row number ', num2str(curJointIdx),' of ',num2str(rob.n),' for ',rob.name,'.']};
hStruct.inputs = { ['rob: robot object of ', rob.name, ' specific class'],...
    ['q:  ',int2str(rob.n),'-element vector of generalized'],...
    '     coordinates',...
    'Angles have to be given in radians!'};
hStruct.outputs = {['Irow:  [1x',int2str(rob.n),'] row of the robot inertia matrix']};
hStruct.references = {'1) Robot Modeling and Control - Spong, Hutchinson, Vidyasagar',...
    '2) Modelling and Control of Robot Manipulators - Sciavicco, Siciliano',...
    '3) Introduction to Robotics, Mechanics and Control - Craig',...
    '4) Modeling, Identification & Control of Robots - Khalil & Dombre'};
hStruct.authors = {'This is an autogenerated function!',...
    'Code generator written by:',...
    'Joern Malzahn',...
    '2012 RST, Technische Universitaet Dortmund, Germany',...
    'http://www.rst.e-technik.tu-dortmund.de'};
hStruct.seeAlso = {'coriolis'};
end

function hStruct = createHeaderStructFullInertia(rob,fname)
[~,hStruct.funName] = fileparts(fname);
hStruct.shortDescription = ['Inertia matrix for the ',rob.name,' arm.'];
hStruct.calls = {['I = ',hStruct.funName,'(rob,q)'],...
    ['I = rob.',hStruct.funName,'(q)']};
hStruct.detailedDescription = {'Given a full set of joint variables the function computes the',...
    'inertia Matrix of the robot.'};
hStruct.inputs = { ['rob: robot object of ', rob.name, ' specific class'],...
    ['q:  ',int2str(rob.n),'-element vector of generalized'],...
    '     coordinates',...
    'Angles have to be given in radians!'};
hStruct.outputs = {['I:  [',int2str(rob.n),'x',int2str(rob.n),'] inertia matrix']};
hStruct.references = {'1) Robot Modeling and Control - Spong, Hutchinson, Vidyasagar',...
    '2) Modelling and Control of Robot Manipulators - Sciavicco, Siciliano',...
    '3) Introduction to Robotics, Mechanics and Control - Craig',...
    '4) Modeling, Identification & Control of Robots - Khalil & Dombre'};
hStruct.authors = {'This is an autogenerated function!',...
    'Code generator written by:',...
    'Joern Malzahn',...
    '2012 RST, Technische Universitaet Dortmund, Germany',...
    'http://www.rst.e-technik.tu-dortmund.de'};
hStruct.seeAlso = {'coriolis'};
end