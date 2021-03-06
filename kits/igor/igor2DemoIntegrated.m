% Testing out balancing robot control.
%
% Assumes using a Sony PS4 Gamepad:
% Model CUH-ZCT2U Wireless Controller
%
% Dave Rollinson
% Apr 2017

function igor2DemoIntegrated( cam_module )
    
localDir = fileparts(mfilename('fullpath'));

addpath(fullfile(localDir));
addpath(fullfile(localDir, 'hebi'));
addpath(fullfile(localDir, 'tools'));
addpath(fullfile(localDir, 'tools', 'gains'));
addpath(fullfile(localDir, 'tools', 'input'));
addpath(fullfile(localDir, 'tools', 'kinematics'));

HebiJoystick.loadLibs();
HebiKeyboard.loadLibs();

% % This is optional, use it to only use the local network.
% HebiLookup.setLookupAddresses('10.10.1.255');

if(cam_module == true)
    numDOFs = 15;  
    moduleNames = { 'wheel1', 'wheel2', ...
                    'hip1', 'knee1', ...
                    'hip2', 'knee2', ...
                    'base1', 'shoulder1', 'elbow1', 'wrist1', ...
                    'base2', 'shoulder2', 'elbow2', 'wrist2', ...
                    'camTilt'};
else
    numDOFs = 14;  
    moduleNames = { 'wheel1', 'wheel2', ...
                    'hip1', 'knee1', ...
                    'hip2', 'knee2', ...
                    'base1', 'shoulder1', 'elbow1', 'wrist1', ...
                    'base2', 'shoulder2', 'elbow2', 'wrist2'};
end

wheelDOFs = [1,2];
legDOFs{1} = 3:4;
legDOFs{2} = 5:6;
armDOFs{1} = 7:10;
armDOFs{2} = 11:14;

while true
    try
        fprintf('Searching for modules...\n');
        robotGroup = HebiLookup.newGroupFromNames('Igor II',moduleNames);
        break;
       
    catch
        %keep going, there are still modules missing
    end
    
    pause(1);
end

fprintf('Found.\n');

%loop until all modules are in application
while true
    moduleInfo = robotGroup.getInfo();
    inBootloader = strcmp('bootloader', moduleInfo.firmwareMode);

    %if any modules are in bootloader just try to boot all of them
    if (any(inBootloader))
        robotGroup.send('boot',true);
    else
        break;
    end      
    
    pause(1);
end

robotGroup.setFeedbackFrequency(100);
pause(1);

fbk = robotGroup.getNextFeedbackFull();
timeLast = fbk.time;

% Load the gains for all the modules
gains = HebiUtils.loadGains([localDir '/igorGains.xml']);

% If there's no camera, remove the camera module from the gains before
% sending them (the camera is the last one in the group).
if cam_module == false
    gainsFields = fields(gains);
    for i=2:length(gainsFields)
        gains.(gainsFields{i})(end) = [];
    end
end

while true
    try
        fprintf('Sending gains\n');
        robotGroup.send('gains',gains);
        break;
    catch
    end
end

robotGroup.setFeedbackFrequency(500);
pause(1);

fbk = robotGroup.getNextFeedbackFull();
timeLast = fbk.time;

animStruct = struct();

%%
%joystick setup

while true        
    try
        fprintf('Searching for joystick...\n');
        joy = HebiJoystick(1)
        
        while joy.Buttons == 0
            pause(1);
            joy = HebiJoystick(1)
        end
        
        [axes, buttons, povs] = read(joy);
        break;
    catch
        %do nothing
    end
    
    robotGroup.send('led','w');
    pause(0.1);
    robotGroup.send('led','m');
    pause(0.1);
end

fprintf('Found.\n');
    
[axes, buttons, povs] = read(joy);

LEFT_STICK_X = 1;
LEFT_STICK_Y = 2;
OPTIONS_BUTTON = 10;
LEFT_TRIGGER_BUTTON = 5;
RIGHT_TRIGGER_BUTTON = 6;
SHARE_BUTTON = 9;
  
if isunix
    SQUARE_BUTTON = 4;
    CIRCLE_BUTTON = 2;
    TRIANGLE_BUTTON = 3;
    X_BUTTON = 1;
    LEFT_STICK_CLICK = 12;
    RIGHT_STICK_CLICK = 13;
    TOUCHPAD_BUTTON = 11;
    LEFT_TRIGGER = 3;
    RIGHT_TRIGGER = 6;
    RIGHT_STICK_X = 4;
    RIGHT_STICK_Y = 5;
else
    SQUARE_BUTTON = 1;
    CIRCLE_BUTTON = 3;
    TRIANGLE_BUTTON = 4;
    X_BUTTON = 2;
    LEFT_STICK_CLICK = 11;
    RIGHT_STICK_CLICK = 12;
    TOUCHPAD_BUTTON = 14;
    LEFT_TRIGGER = 4;
    RIGHT_TRIGGER = 5;
    RIGHT_STICK_X = 3;
    RIGHT_STICK_Y = 6;
end

%%
%Workaround for bug that makes the triggers not work correctly until they
%are both pushed down fully for the first time. Also checks for a bug where
%all of the axes are initialized to -1 in linux.

if isunix
    while(axes(LEFT_TRIGGER)~=-1.000 || axes(RIGHT_TRIGGER)~=-1.000 || ...
          axes(RIGHT_STICK_X)~= 0 || axes(RIGHT_STICK_Y)~= 0 || ...
          axes(LEFT_STICK_X)~= 0 || axes(LEFT_STICK_Y)~= 0)
        [axes, buttons, povs] = read(joy);
        axes
        robotGroup.send('led','b');
        pause(0.1);
        robotGroup.send('led','m');
        pause(0.1)
    end
else
    while(axes(LEFT_TRIGGER)~=-1.000 || axes(RIGHT_TRIGGER)~=-1.000)
        [axes, buttons, povs] = read(joy);
        robotGroup.send('led','b');
        pause(0.1);
        robotGroup.send('led','m');
        pause(0.1)
    end
end

%wait to start
while true
    fprintf('Paused. Click left stick to start, share to quit matlab...\n');  

    try
        [axes, buttons, povs] = read(joy);
    catch
        fprintf('joystick error \n'); 
        try
            fprintf('Searching for joystick...\n');
            joy = HebiJoystick(1)

            if joy.Buttons == 0
                joy = HebiJoystick(2)
            end

            [axes, buttons, povs] = read(joy);
        catch
            %do nothing
        end
    end
    
    while(buttons(LEFT_STICK_CLICK) == 0)
        try
            [axes, buttons, povs] = read(joy);
        catch
            fprintf('joystick error \n');
            try
                fprintf('Searching for joystick...\n');
                joy = HebiJoystick(1)

                if joy.Buttons == 0
                    joy = HebiJoystick(2)
                end

                [axes, buttons, povs] = read(joy);
            catch
            %do nothing
            end
        end
        
        if(buttons(SHARE_BUTTON))
            robotGroup.send('led',[]);
            quit force
        end
        pause(0.1);
        robotGroup.send('led','m');
        pause(0.1);
        robotGroup.send('led','g');
        
    end
    
    axes(LEFT_STICK_X) = 0;
    axes(LEFT_STICK_Y) = 0;
    axes(RIGHT_STICK_X) = 0;
    axes(RIGHT_STICK_Y) = 0;
    axes(LEFT_TRIGGER) = -1;
    axes(RIGHT_TRIGGER) = -1;
            
    axesLast = axes;
      
    fprintf('Running. Click left stick to stop...\n');
    
    %Get initial feedback
    try
        fbk = robotGroup.getNextFeedback( fbk );
    catch
        disp('Could not get feedback!');
        break;
    end

    balanceOn = true;
    logging = true;   % Flag to turn logging on and off.  If logging is on you 
                      % you can view a bunch of debug plots after quitting.

    cmd = CommandStruct();
    cmd.position = nan(1,numDOFs);
    cmd.velocity = nan(1,numDOFs);
    cmd.effort = nan(1,numDOFs);

    direction = [1, -1];

    wheelRadius = .200 / 2;  % m
    wheelBase = .43;  % m

    % THESE VALUES ARE VERY APPROXIMATE
    chassisCoM = [0; 0; .10 + .3];  % XYZ center of mass (m)
                                    % center of chassis on hip axis
    chassisMass = 6;  % kg  (9 is closer to true value)

    numLegs = 2;
    numArms = 2;

    J_limit = .010;

    gripVelCmd = zeros(3,1);
    gripVel = zeros(3,numArms);
    
    wristVel = 0;
    hipPitchVel = 0;

    camTiltVel = 0;
    camTiltPos = 0;

    hipPosComp = -.0;
    hipPitch = 0;

    %imuModules = [1:6,7,11];
    imuModules = [1:6];
    %imuModules = [3 5]; 

    R_hip1 = R_x(-pi/2);
    R_hip2 = R_x(pi/2);

    leanAngleErrorCum = 0;
    chassisVelErrorCum = 0;
    fbkChassisVelLast = 0;
    cmdChassisVelLast = 0;

    timeHist = nan(0,1);
    cmdLeanAngleHist = nan(0,1);
    fbkLeanAngleHist = nan(0,1);
    leanAngleVelHist = nan(0,1);
    leanAngleOffsetHist = nan(0,1);
    cmdChassisVelHist = nan(0,1);
    fbkChassisVelHist = nan(0,1);
    RPYHist = nan(0,3);
    RPY_moduleHist = nan(0,3*numDOFs);
    
    T_pose = eye(4);

    %%%%%%%%%%%%%%%%%%
    % Leg Kinematics %
    %%%%%%%%%%%%%%%%%%

    kneeAngle = deg2rad(130);
    hipAngle = pi/2 + kneeAngle/2;
    legHomeAngles = [ hipAngle  kneeAngle;
                     -hipAngle -kneeAngle ];

    % Setup Legs
    R_hip = R_x(pi/2);
    xyz_hip = [0; .0225; .055]; 
    T_hip = eye(4);
    T_hip(1:3,1:3) = R_hip;
    T_hip(1:3,4) = xyz_hip;

    legBaseFrames(:,:,1) = eye(4);
    legBaseFrames(:,:,2) = eye(4);

    legBaseFrames(1:3,4,1) = [0; .15; 0];
    legBaseFrames(1:3,4,2) = [0; -.15; 0];

    legBaseFrames(1:3,1:3,1) = R_x(-pi/2);
    legBaseFrames(1:3,1:3,2) = R_x(pi/2);

    for leg = 1:numLegs
        legKin{leg} = HebiKinematics();
        legKin{leg}.addBody('X5-9');
        legKin{leg}.addBody('X5Link','ext',.375,'twist',pi);
        legKin{leg}.addBody('X5-4');
        legKin{leg}.addBody('X5Link','ext',.325,'twist',pi);

        legKin{leg}.setBaseFrame(legBaseFrames(:,:,leg));
    end

    
    %%%%%%%%%%%%%%%%%%
    % Arm Kinematics %
    %%%%%%%%%%%%%%%%%%

    armBaseXYZ(:,1) = [0; .10; .20];
    armBaseXYZ(:,2) = [0; -.10; .20];

    mounting = {'left-inside','right-inside'};

    for arm = 1:numArms
        armKin{arm} = HebiKinematics();
        armKin{arm}.addBody('X5-4');
        armKin{arm}.addBody('X5-HeavyBracket', 'mount', mounting{arm} );
        armKin{arm}.addBody('X5-9');
        armKin{arm}.addBody('X5Link','ext',.325,'twist',0,'mass',.250);
        armKin{arm}.addBody('X5-4');
        armKin{arm}.addBody('X5Link','ext',.325,'twist',pi,'mass',.350);
        armKin{arm}.addBody('X5-4');

        armTransform = eye(4);
        armTransform(1:3,4) = armBaseXYZ(:,arm);
        armKin{arm}.setBaseFrame(armTransform);
    end

    armHomeAngles(1,:) = deg2rad([0 20 60 0]);
    armHomeAngles(2,:) = deg2rad([0 -20 -60 0]);

    armJointAngs = armHomeAngles';
    newArmJointAngs = armJointAngs;
    armJointVels = zeros(size(armJointAngs));
    newArmJointVels = armJointVels;
    
    for arm = 1:numArms
        T_endEffector = armKin{arm}.getFK('endeffector',armHomeAngles(arm,:));
        gripPos(:,arm) = T_endEffector(1:3,4);
    end

    gripPos(2,2) = -gripPos(2,2);
    gripPos = repmat(mean(gripPos,2),1,2);
    gripPos(2,2) = -gripPos(2,2);

    if logging
        robotGroup.startLog();
    end
    
    % Trajectory Generator for the chassis velocity
    chassisTrajGen = HebiTrajectoryGenerator();
    chassisTrajGen.setSpeedFactor(1.0);
    
    numCmds = 6;
    
    chassisVelNow = zeros(1,numCmds);
    chassisAccNow = zeros(1,numCmds);
    chassisJerkNow = zeros(1,numCmds);
    
    chassisCmdVel = zeros(1,numCmds);
    minRampTime = .5;
    rampTime = minRampTime;
    
    time = [ 0 rampTime ];
    chassisVels = [chassisVelNow; chassisCmdVel];
    chassisAccels = [chassisAccNow; zeros(1,numCmds) ];
    chassisJerks = [chassisJerkNow; zeros(1,numCmds)];
    
    chassisTraj = chassisTrajGen.newJointMove( chassisVels, ...
        'Velocities', chassisAccels, ...
        'Accelerations', chassisJerks, ...
        'Time', time );
    chassisTrajTimer = tic;

    %%
    %%%%%%%%%%%%%%%%
    % Soft Startup %
    %%%%%%%%%%%%%%%%

    %run robot controller
    robotGroup.send('led',[]);
    startupTime = 3.0;
    time = [ 0 startupTime ];

    for i = 1:2

        % Leg Trajectory Generator
        trajGenLegs{i} = HebiTrajectoryGenerator(legKin{i});
        trajGenLegs{i}.setSpeedFactor(1);
        trajGenLegs{i}.setAlgorithm('UnconstrainedQp');

        pos = [ fbk.position(legDOFs{i}); 
                legHomeAngles(i,:) ];
        vel = zeros(2,2);
        accel = zeros(2,2);

        legTraj{i} = trajGenLegs{i}.newJointMove( pos, ...
                    'Velocities', vel, ...
                    'Accelerations', accel, ...
                    'Time', time );

        % Arm Trajectory Generator
        trajGenArms{i} = HebiTrajectoryGenerator(armKin{i});
        trajGenArms{i}.setSpeedFactor(1);

        pos = [ fbk.position(armDOFs{i}); 
                armHomeAngles(i,:) ];
        vel = zeros(2,4);
        accel = zeros(2,4);

        armTraj{i} = trajGenArms{i}.newJointMove( pos, ...
                    'Velocities', vel, ...
                    'Accelerations', accel, ...
                    'Time', time );        
    end   

    % Initialize Pose Filter
    poseFilter = HebiPoseFilter();
    poseFilter.setMaxAccelWeight( .01);
    poseFilter.setMaxAccelNormDev( .3 );
    filterTime = fbk.time;

    trajTimer = tic;       
    t = toc(trajTimer);

    while t < startupTime

        t = toc(trajTimer);

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Update date filtered pose estimate %
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        try
            fbk = robotGroup.getNextFeedback( fbk );
        catch
            disp('Could not get feedback!');
            break;
        end

        % Limit commands initially
        softStart = min(t/startupTime,1);

        for i=1:2
            [posNow, velNow, accNow] = legTraj{i}.getState(t);
            cmd.position(legDOFs{i}) = posNow;
            cmd.velocity(legDOFs{i}) = velNow;

            [posNow, velNow, accNow] = armTraj{i}.getState(t);
            cmd.position(armDOFs{i}) = posNow;
            cmd.velocity(armDOFs{i}) = velNow;

            % Gravity Compensation Torques
            cmd.effort(armDOFs{i}) = armKin{i}.getGravCompEfforts( ...
                                    fbk.position(armDOFs{i}), ...
                                    -T_pose(3,1:3) );                     
        end

        cmd.effort = softStart * cmd.effort;   
        robotGroup.send(cmd);
    end

    warmupTimer = tic;
    warmupDuration = 1;  % sec

    while true

        % Limit commands initially
        softStart = min(toc(warmupTimer)/warmupDuration,1);

        try
            fbk = robotGroup.getNextFeedback( fbk );
        catch
            disp('Could not get feedback!');
            break;
        end
        dt = mean(fbk.time - timeLast);
        timeLast = fbk.time;
        
        %%%%%%%%%%%%%%%%%%%%%%
        % Get Leg Kinematics %
        %%%%%%%%%%%%%%%%%%%%%%
        for leg=1:numLegs
            legCoMs{leg} = legKin{leg}.getFK('com',fbk.position(legDOFs{leg}));
            legFK{leg} = legKin{leg}.getFK('output',fbk.position(legDOFs{leg}));
            legTipFK{leg} = legKin{leg}.getFK( 'endeffector', ...
                                    fbk.position(legDOFs{leg}) );
            J_legFbk{leg} = legKin{leg}.getJacobianEndEffector( ...
                                    fbk.position(legDOFs{leg}) );                       
    %         det_J_fbk(leg) = abs(det(J_fbk{leg}(1:3,:)));        

            J_legCmd{leg} = legKin{leg}.getJacobianEndEffector( ...
                                    fbk.positionCmd(legDOFs{leg}) );
    %         det_J_cmd(leg) = abs(det(J_cmd{leg}(1:3,:))); 

            legXYZ = squeeze(legCoMs{leg}(1:3,4,:));
            legMasses = legKin{leg}.getBodyMasses;
            legCoM(:,leg) = sum( legXYZ.*repmat(legMasses',3,1), 2 ) / sum(legMasses);
            legMass(leg) = sum(legMasses);
        end

        %%%%%%%%%%%%%%%%%%%%%%
        % Get Arm Kinematics %
        %%%%%%%%%%%%%%%%%%%%%%
        for i=1:numArms
            armFK{i} = armKin{i}.getFK('com',fbk.position(armDOFs{i}));
            armTipFK{i} = armKin{i}.getFK( 'endeffector', ...
                                    fbk.position(armDOFs{i}) );
            J_armFbk{i} = armKin{i}.getJacobianEndEffector( ...
                                    fbk.position(armDOFs{i}) );                       
            det_J_fbk(i) = abs(det(J_armFbk{i}(1:3,1:3)));        

            J_armCmd{i} = armKin{i}.getJacobianEndEffector( ...
                                    fbk.positionCmd(armDOFs{i}) );
            det_J_cmd(i) = abs(det(J_armCmd{i}(1:3,1:3))); 

            armXYZ = squeeze(armFK{i}(1:3,4,:));
            armMasses = armKin{i}.getBodyMasses;
            armCoM(:,i) = sum( armXYZ.*repmat(armMasses',3,1), 2 ) / sum(armMasses);
            armMass(i) = sum(armMasses);
        end

        % Adjust CoM based on chassis, leg configuration
        allCoMs = [legCoM armCoM chassisCoM];
        allMasses = [legMass armMass chassisMass];

        robotCoM = sum(allCoMs .* repmat(allMasses,3,1), 2) / sum(allMasses);
        robotMass = sum(allMasses);

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Update date filtered pose estimate %
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        poseAccel = [fbk.accelX; fbk.accelY; fbk.accelZ];
        poseGyro = [fbk.gyroX; fbk.gyroY; fbk.gyroZ];

        Q_modules = [ fbk.orientationW;
                      fbk.orientationX;
                      fbk.orientationY;
                      fbk.orientationZ ];

        imuFrames(:,:,1) = legFK{1}(:,:,4);
        imuFrames(:,:,2) = legFK{2}(:,:,4);
        
        imuFrames(:,:,3) = legKin{1}.getBaseFrame;
        imuFrames(:,:,4) = legFK{1}(:,:,2);
        
        imuFrames(:,:,5) = legKin{2}.getBaseFrame;
        imuFrames(:,:,6) = legFK{2}(:,:,2);
        
        imuFrames(:,:,7) = armKin{1}.getBaseFrame;
        imuFrames(:,:,8) = armFK{1}(:,:,2);
        imuFrames(:,:,9) = armFK{1}(:,:,4);
        imuFrames(:,:,10) = armFK{1}(:,:,6);
        
        imuFrames(:,:,11) = armKin{2}.getBaseFrame;
        imuFrames(:,:,12) = armFK{2}(:,:,2);
        imuFrames(:,:,13) = armFK{2}(:,:,4);
        imuFrames(:,:,14) = armFK{2}(:,:,6);
        
        imuFrames(:,:,15) = eye(4);

        rotComp = zeros(3,numDOFs);

        for i=1:numDOFs
            poseAccel(:,i) = imuFrames(1:3,1:3,i) * poseAccel(:,i);
            poseGyro(:,i) = imuFrames(1:3,1:3,i) * (poseGyro(:,i) + rotComp(:,i));
            
            DCM_module = HebiUtils.quat2rotMat(Q_modules(:,i)');
            DCM_module = DCM_module * imuFrames(1:3,1:3,i)';
            try
                RPY = SpinCalc('DCMtoEA123',DCM_module,1E-9,0);
            catch
                % fprintf('Module %d is near singularity.\n', i);
                % keyboard
                RPY = [nan nan nan];
            end
            RPY(RPY>180) =  RPY(RPY>180) - 360;
            
            RPY_module(i,:) = -RPY;
        end

        poseAccelMean = mean(poseAccel(:,imuModules),2,'omitnan');
        poseGyroMean = mean(poseGyro(:,imuModules),2,'omitnan');

        
        %%%%%%%%%%%%%%%%%%%%%%%%
        % Calculate Lean Angle %
        %%%%%%%%%%%%%%%%%%%%%%%%  
       
        rollAngle = mean(RPY_module(imuModules,1),'omitnan');
        pitchAngle = mean(RPY_module(imuModules,2),'omitnan');
        
        rollR = R_x(deg2rad(rollAngle));
        leanR = R_y(deg2rad(pitchAngle));
        
        T_pose(1:3,1:3) = leanR * rollR;

        leanAngle = pitchAngle;
        leanAngleVel = poseGyroMean(2);
    %     
    %     leanAngleOffset = 0;
    %     fbkLeanAngle = leanAngle - leanAngleOffset;

        groundPoint = mean([legTipFK{1}(1:3,4),legTipFK{2}(1:3,4)],2);      
        lineCoM = leanR*(robotCoM - groundPoint);
        heightCoM = norm(lineCoM);

        fbkLeanAngle = rad2deg(atan2(lineCoM(1),lineCoM(3)));

        robotCoM = T_pose(1:3,1:3) * robotCoM;
        for leg=1:numLegs
            for i=1:size(legCoMs{leg},3)
                legCoMs{leg}(:,:,i) = T_pose * legCoMs{leg}(:,:,i);
            end
            legTipLeanFK{leg} = T_pose * legTipFK{leg};
        end

    %     plotFrames = cat(3,T_pose,legCoMs{1},legCoMs{2},legTipLeanFK{1},legTipLeanFK{2});
    %     animStruct = drawAxes(animStruct,plotFrames,.1*ones(3,1));
    %     drawnow;

        %%%%%%%%%%%%%%%%%%
        % Joystick Input %
        %%%%%%%%%%%%%%%%%%

        try
            [axes, buttons, povs] = read(joy);
        catch
            disp('Joystick Error');
            axes(LEFT_STICK_X) = 0;
            axes(LEFT_STICK_Y) = 0;
            axes(RIGHT_STICK_X) = 0;
            axes(RIGHT_STICK_Y) = 0;
            axes(LEFT_TRIGGER) = -1;
            axes(RIGHT_TRIGGER) = -1;
        end
        
        joyLowPass = .95;
%         axes = joyLowPass * axesLast + ...
%                         (1-joyLowPass) * axes;
%         axesLast = axes;  

        if buttons(RIGHT_STICK_CLICK)
            break;
        end

        if buttons(TOUCHPAD_BUTTON)
            balanceOn = false;
        else
            balanceOn = true;
        end
        
        % Chassis Fwd / Back Vel
        joyScale = -.5;
        joyDeadZone = .06;
        if abs(axes(RIGHT_STICK_Y)) > joyDeadZone
            cmdVelJoy = joyScale * (axes(RIGHT_STICK_Y) - joyDeadZone*sign(axes(RIGHT_STICK_Y)));
        else
            cmdVelJoy = 0;
        end

        % Chassis Yaw Vel
        if abs(axes(RIGHT_STICK_X)) > joyDeadZone
            rotDiffJoy = 25 * wheelRadius * direction(1) / wheelBase * ...
                            (axes(RIGHT_STICK_X) - joyDeadZone*sign(axes(RIGHT_STICK_X)));
        else
            rotDiffJoy = 0;
        end
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % SET THIS PARAMETER TO ZERO IF TORQUE SENSING ON SHOULDER IS BAD %
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        shoulderTorqueScale = 5;
        %shoulderTorqueScale = 0;
        
        % Comply to efforts from the arm
        armBaseTorque = mean(fbk.effort([armDOFs{1}(1),armDOFs{2}(1)]));
        rotCompDZ = 0.75;
        if (abs(armBaseTorque) > rotCompDZ) && balanceOn
            rotComp = shoulderTorqueScale * ...
                           (armBaseTorque - rotCompDZ*sign(armBaseTorque));
        else
            rotComp = 0;
        end
        %rotDiffJoy =  rotDiffJoy + rotComp;
        
        % Stance Height
        if (buttons(OPTIONS_BUTTON))
            %Use button 2 for a soft shutdown procedure
            kneeVelJoy = 1.0;
            %hipVelocity = kneeVelJoy/2;
            %Lower robot until kneeAngle threshold before exiting
            if(kneeAngle > 2.5)
                break;
            end
        else
            % Normal Stance Height control
            if abs(axes(LEFT_TRIGGER)-axes(RIGHT_TRIGGER)) > joyDeadZone  
                kneeVelJoy = .5 * (axes(LEFT_TRIGGER)-axes(RIGHT_TRIGGER));
                %hipVelocity = kneeVelJoy/2;
            else
                kneeVelJoy = 0;
                %hipVelocity = 0;
            end
        end

        % Arm Y-Axis
        if abs(axes(LEFT_STICK_X)) > joyDeadZone*3
            gripVelCmd(2) = -.4 * axes(LEFT_STICK_X);
        else
            gripVelCmd(2) = 0;
        end

        % Arm X-Axis
        if abs(axes(LEFT_STICK_Y)) > joyDeadZone
            gripVelCmd(1) = -.4 * axes(LEFT_STICK_Y);
        else
            gripVelCmd(1) = 0;
        end

        % Arm Z-Axis
        if buttons(RIGHT_TRIGGER_BUTTON)
            gripVelCmd(3) = .2;
        elseif buttons(LEFT_TRIGGER_BUTTON)
            gripVelCmd(3) = -.2;
        else
            gripVelCmd(3) = 0;
        end

        % Wrist Rotation
        if povs == 0
            wristVel = joyLowPass*wristVel - (1-joyLowPass)*2.5;
        elseif povs == 180
            wristVel = joyLowPass*wristVel + (1-joyLowPass)*2.5;
        else
            wristVel = joyLowPass*wristVel;
        end

        % Make the left arm temporarily compliant
        if povs == 90
            leftArmCompliant = true;
        else
            leftArmCompliant = false;
        end

        %Camera Tilt
        if buttons(CIRCLE_BUTTON)
            camTiltPos = 1.4;
        elseif buttons(SQUARE_BUTTON)   
            camTiltPos = 0;
        else
            camTiltPos = nan;
            if buttons(TRIANGLE_BUTTON)
                camTiltVel = -0.6;
            elseif buttons(X_BUTTON)
                camTiltVel = 0.6;
            else
                camTiltVel = 0;
            end 
        end
        
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Smooth trajectories for various commands, replan evey timestep %
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        t = toc(chassisTrajTimer);
        [chassisVelNow, chassisAccNow, chassisJerkNow] = chassisTraj.getState(t);
        
        chassisCmdVel = [cmdVelJoy rotDiffJoy kneeVelJoy gripVelCmd'];
        
        time = [ 0 minRampTime ];
        chassisVels = [chassisVelNow; chassisCmdVel];
        chassisAccels = [chassisAccNow; zeros(1,numCmds) ];
        chassisJerks = [chassisJerkNow; zeros(1,numCmds) ];
        
        chassisTraj = chassisTrajGen.newJointMove( chassisVels, ...
            'Velocities', chassisAccels, ...
            'Accelerations', chassisJerks, ...
            'Time', time );
        chassisTrajTimer = tic;
    
        cmdVel = chassisVelNow(1);
        rotDiff = chassisVelNow(2) + rotComp;
        
        kneeVelocity = chassisVelNow(3);
        hipVelocity = kneeVelocity/2;
        
        gripVel = repmat(chassisVelNow(4:6)',1,numArms);


        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Control the Leg Positions %
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%

        % Joint Limits
        kneeAngleMax = 2.65;
        kneeAngleMin = .65;

        if (kneeAngle > kneeAngleMax && kneeVelocity > 0) || ...
           (kneeAngle < kneeAngleMin && kneeVelocity < 0)
            kneeVelocity = 0;
            hipVelocity = 0;
        end

        hipPitch = hipPitch + hipPitchVel*dt;

        kneeAngle = kneeAngle + kneeVelocity * dt;
        hipAngle = pi/2 + kneeAngle/2 + hipPitch;


        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Control the Arm End Effector Positions %
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

        % Make end effector velocities mirrored in Y, integrate velocity
        % commmands to get new positions.
        
        gripVel(2,2) = -gripVel(2,2);

    %     % Used if keeping arms stationary in world frame
    %     if armVelComp
    %         gripVel(1,:) = gripVel(1,:) + fbkChassisVel;
    %     end

        %gripVel = R_y(fbkLeanAngle) * gripVel;

        oldGripPos = gripPos;
        if leftArmCompliant
            newGripPos(:,1) = armTipFK{1}(1:3,4);
            newGripPos(:,2) = gripPos(:,2);
        else
            newGripPos = gripPos + gripVel*dt;
        end
        gripWidthLim = .00;
        if newGripPos(2,1) < gripWidthLim
            newGripPos(2,:) = [gripWidthLim, -gripWidthLim];
        end

        % Use Jacobian inverse to get joint velocities from desired XYZ vel
        for i=1:numArms
            newArmJointAngs(:,i) = armKin{i}.getIK( ...
                                    'xyz', newGripPos(:,i), ...
                                    'initial', fbk.position(armDOFs{i}) );
            newArmJointVels(:,i) = J_armFbk{i}(1:3,:) \ gripVel(:,i);

            J_new{i} = armKin{i}.getJacobianEndEffector( ...
                                    newArmJointAngs(:,i) );                       
            det_J_new(i) = abs(det(J_new{i}(1:3,1:3)));
        end

        % Check manipulability to make sure arms don't go to singularity
        if (min(det_J_cmd) < J_limit) && min(det_J_new) < min(det_J_cmd)
            gripPos = oldGripPos;
            armJointAngs(1:3,:) = armJointAngs(1:3,:);
            armJointVels(1:3,:) = zeros(size(newArmJointVels(1:3,:)));
        else
            gripPos = newGripPos;
            armJointAngs(1:3,:) = newArmJointAngs(1:3,:);
            armJointVels(1:3,:) = newArmJointVels(1:3,:);
        end

        % Handle the wrist separately
        armJointVels(4,:) = armJointVels(2,:) + armJointVels(3,:) + ...
                                direction * wristVel;
        armJointAngs(4,:) = armJointAngs(4,:) + armJointVels(4,:)*dt;

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % Chassis Velocity Controller %
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

        cmdChassisVel = cmdVel;

        % PID Controller that set a desired lean angle
        velP = 5 / .33;
        velI = 3 / 30;
        velD = .3 / 1;

        fbkChassisVel = wheelRadius * mean(direction.*fbk.velocity(1:2)) + ...
                         heightCoM*leanAngleVel;

        chassisVelError = cmdChassisVel - fbkChassisVel;

        chassisVelErrorCum = chassisVelErrorCum + chassisVelError*dt;

        % chassisVelErrorCum = softStart * chassisVelErrorCum;
        chassisVelErrorCum = min(abs(chassisVelErrorCum),5/velI) * ...
                                        sign(chassisVelErrorCum);

        cmdChassisAccel = (cmdChassisVel - cmdChassisVelLast) / dt;
        cmdChassisVelLast = cmdChassisVel;

        chassisAccel = (fbkChassisVel - fbkChassisVelLast) / dt;
        fbkChassisVelLast = fbkChassisVel;

        leanFF = 0.1 * robotMass * cmdChassisAccel / heightCoM;
        velFF = direction * cmdChassisVel / wheelRadius;

        cmdLeanAngle = velP * chassisVelError + ...
                       velI * chassisVelErrorCum + ...
                       velD * chassisAccel + ... newGripPos(:,1) = gripPos(:,1);
                       leanFF;

        % Reset the Command Struct                            
        cmd.effort = nan(1,numDOFs);
        cmd.position = nan(1,numDOFs);
        cmd.velocity = nan(1,numDOFs);

        
        % Lean Angle Control
        leanAngleError = fbkLeanAngle - cmdLeanAngle;
        leanAngleErrorLast = leanAngleError;

        leanAngleErrorCum = leanAngleErrorCum + leanAngleError * dt;
        leanAngleErrorCum = min(abs(leanAngleErrorCum),.2) * ...
                                        sign(leanAngleErrorCum);

                                    
        %%%%%%%%%%%%%%%%%%%%%%%%%%%
        % COMMANDS FOR THE WHEELS %
        %%%%%%%%%%%%%%%%%%%%%%%%%%%               
        % Torques are commanded based lean angle controller
        % 
        % NOTE: Gains for the wheel modules are set so that only the FF term is
        % active in effort and velocity.  This lets you control PWM directly
        % while still working in more intuitive units for velocity and effort.
        if balanceOn         
            % PID Controller to servo to a desired lean angle
            leanP = 1.0;
            leanI = 20;
            leanD = 10;

            cmd.effort(wheelDOFs) = direction*leanP*leanAngleError + ...
                                    direction*leanI*leanAngleErrorCum + ...
                                    direction*leanD*leanAngleVel;  

            cmd.effort(wheelDOFs) = softStart * cmd.effort(wheelDOFs);                
        end

        maxVel = 10; % rad / sec
        cmd.velocity(wheelDOFs) = min(max(rotDiff + velFF,-maxVel),maxVel);


        %%%%%%%%%%%%%%%%%%%%%%%%%
        % COMMANDS FOR THE LEGS %
        %%%%%%%%%%%%%%%%%%%%%%%%%
        for leg=1:numLegs
            cmd.position(legDOFs{leg}) = ...
                            direction(leg) * [ hipAngle kneeAngle];
            cmd.velocity(legDOFs{leg}) = ...
                            direction(leg) * [ hipVelocity kneeVelocity ];
        end

        % Impedence Control Params
        damperGains = [2; 0; 1; .0; .0; .0;]; % N or Nm / m/s
        springGains = [400; 0; 100; 0; 0; 0];  % N/m or Nm/rad

        rollGains = [0; 0; 10; 0; 0; 0];  % N or Nm / deg
        rollSign = [1 -1];

        for leg=1:numLegs
            % Impedence Control Torques
            legTipCmdFK = legKin{leg}.getFK( 'endeffector', ...
                                    cmd.position(legDOFs{leg}) );
            xyzError = legTipCmdFK(1:3,4) - legTipFK{leg}(1:3,4);
            posError = [xyzError; zeros(3,1)];

            velError = J_legFbk{leg} * ( cmd.velocity(legDOFs{leg}) - ...   
                                    fbk.velocity(legDOFs{leg}) )';                    

            impedanceTorque = J_legFbk{leg}' * ...
                            (springGains .* posError + ...
                             damperGains .* velError + ...
                             rollGains .* rollAngle*rollSign(leg)); 

            % Gravity Compensation Torques
            %gravCompTorque = J_legFbk{leg}(1:3,:)' * 9.8*[0; 0; -robotMass/4];
            gravCompTorque = zeros(2,1);

            cmd.effort(legDOFs{leg}) = softStart*( impedanceTorque' + ...
                                                    gravCompTorque' );                  
        end


        %%%%%%%%%%%%%%%%%%%%%%%%%
        % COMMANDS FOR THE ARMS %
        %%%%%%%%%%%%%%%%%%%%%%%%%
        % Arms are controlled in a more traditional way with position /
        % velocity and efforts like with fixed base manipulation.

        % Impedence Control Params
        damperGains = [1; 1; 1; .0; .0; .0;]; % N or Nm / m/s
        springGains = [100; 10; 100; 0; 0; 0];  % N/m or Nm/rad

        for i = 1:numArms

            % Impedence Control Torques
            xyzError = newGripPos(:,i) - armTipFK{i}(1:3,4);
            posError = [xyzError; zeros(3,1)];

            velError = J_armFbk{i} * ( armJointVels(:,i)' - ...   
                                    fbk.velocity(armDOFs{i}) )';                    

            impedanceTorque = J_armFbk{i}' * ...
                            (springGains .* posError + ...
                             damperGains .* velError); 

            % Gravity Compensation Torques
            gravCompTorque = armKin{i}.getGravCompEfforts( ...
                                    fbk.position(armDOFs{i}), ...
                                    -T_pose(3,1:3) );             

            % Fill in the appropriate part of the Command Struct     
            cmd.effort(armDOFs{i}) = softStart*impedanceTorque' + ...
                                                           gravCompTorque;
            cmd.position(armDOFs{i}) = armJointAngs(:,i);
            cmd.velocity(armDOFs{i}) = armJointVels(:,i);

    %         if i==2
    %             cmd.effort(armDOFs{i}) = softStart*impedanceTorque' + ...
    %                                                          gravCompTorque;
    %             cmd.position(armDOFs{i}) = armJointAngs(:,i);
    %             cmd.velocity(armDOFs{i}) = armJointVels(:,i);
    %         else 
    %             cmd.effort(armDOFs{i}) = gravCompTorque;
    %             cmd.position(armDOFs{i});
    %             cmd.velocity(armDOFs{i}) = 0;
    %         end
        end

        if(cam_module == 1)
            cmd.velocity(15) = camTiltVel;
            cmd.position(15) = camTiltPos;
        end

        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        % SEND COMMANDS TO THE ROBOT %
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        robotGroup.send(cmd);

        if logging
            timeHist(end+1,1) = fbk.time;
            cmdLeanAngleHist(end+1,1) = cmdLeanAngle;
            fbkLeanAngleHist(end+1,1) = fbkLeanAngle;
            leanAngleVelHist(end+1,1) = leanAngleVel;
            %leanAngleOffsetHist(end+1,1) = leanAngleOffset;
            cmdChassisVelHist(end+1,1) = cmdChassisVel;
            fbkChassisVelHist(end+1,1) = fbkChassisVel;
            RPYHist(end+1,:) = RPY;
            RPY_moduleHist(end+1,:) = RPY_module(:);
        end
    end

    pause(1.0);
    
end

%%
%%%%%%%%%%%%
% PLOTTING %
%%%%%%%%%%%%
if logging
    log = struct(robotGroup.stopLog('view','debug'));
    timeHist = timeHist - timeHist(1);

    % PLOTTING
    figure(101);
    plot(timeHist,fbkLeanAngleHist,'b');
    hold on;
    plot(timeHist,cmdLeanAngleHist,'r');
    hold off;
    title('Lean Angle Tracking');
    xlabel('time (sec)');
    ylabel('angle (deg)');
    legend('Fbk Lean Angle','Cmd Lean Angle');

    figure(102);
    plot(timeHist,fbkChassisVelHist,'b');
    hold on;
    plot(timeHist,leanAngleVelHist,'g');
    plot(timeHist,cmdChassisVelHist,'r');
    hold off;
    title('Chassis Velocity Tracking');
    xlabel('time (sec)');
    ylabel('velocity (m/sec)');
    
    legend('Fbk Chassis Vel','Fbk Lean Angle Vel','Cmd Chassis Vel');
    

%     figure(103); 
%     fbkChassisAccel = smooth(diff(fbkChassisVelHist)./diff(timeHist),100);
%     plot(timeHist(2:end),5*fbkChassisAccel);
%     hold on;
%     fbkOffset = mean(fbkChassisAccel-fbkLeanAngleHist(2:end));
%     plot(timeHist,fbkLeanAngleHist+fbkOffset);
%     plot(timeHist,cmdLeanAngleHist+fbkOffset,'--');
%     hold off;
%     title('Lean Angle Debugging'
%     legend('Chassis Accel Debug','Feedback Lean Angle','Command Lean Angle');
%     xlabel('time (sec)');
%     ylabel('angle (deg)');

    % figure(104);
    % ax = subplot(1,1,1);
    % plot(log.time, direction .* log.velocity(:,wheelDOFs));
    % hold on;
    % ax.ColorOrderIndex = 1;
    % plot(log.time, direction .* log.velocityCmd(:,wheelDOFs),'--');
    % hold off;
end


