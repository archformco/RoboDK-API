% This is an example that uses the RoboDK API for Matlab.
% This is a .m file (Matlab file).
% The RoboDK API for Matlab requires the files in this folder.
% This example requires RoboDK to be running 
% (otherwise, RoboDK will be started if it was installed in the default location)
% This example automatically loads the Example 01 installed by default in the "Library" folder

% Note: This program is not meant to accomplish a specific goal, only to
% show how to use the Matlab API
% 
% RoboDK api Help:
% ->Type "doc Robolink"            for more help on the Robolink class
% ->Type "doc RobolinkItem"        for more help on the RobolinkItem item class
% ->Type "showdemo Example_RoboDK" for examples on how to use RoboDK's API using the last two classes

clc
clear
close all

% Generate a Robolink object RDK. This object interfaces with RoboDK.
RDK = Robolink;

% Get the library path
path = RDK.getParam('PATH_LIBRARY');

% Open example 1
RDK.AddFile([path,'Example 01 - Pick and place.rdk']);

% Display a list of all items
fprintf('Available items in the station:\n');
disp(RDK.ItemList());

% Get one item by its name
program = RDK.Item('Pick and place');

% Start "Pick and place" program
program.RunProgram();

% Alternative call to run the program
% program = RDK.Item('Pick and place').RunProgram();

% Another alternative call to run the same program
% RDK.RunProgram('Pick and place');

% return;

%% Retrieving objects from the station and modifying them

% Get some items in the station by their name. Each item is visible in the
% current project tree

robot = RDK.Item('ABB IRB 1600-8/1.45');
fprintf('Robot selected:\t%s\n', robot.Name());
robot.setVisible(1);
% We can validate the type of each item by calling:
% robot.Type()
% We can retreive the item position with respect to the station with PoseAbs()
% robot.PoseAbs()

frameref = robot.Parent();
fprintf('Robot reference selected:\t%s\n', frameref.Name());

object = RDK.Item('base');
fprintf('Object selected:\t%s\n', object.Name());

ball = RDK.Item('ball');
fprintf('Ball selected:\t%s\n', ball.Name());

frametable = RDK.Item('Table 1');
fprintf('Table selected:\t%s\n', frametable.Name());

tool = RDK.Item('Tool');
fprintf('Tool selected:\t%s\n', tool.Name());

target1 = RDK.Item('Target b1');
fprintf('Target 1 selected:\t%s\n', target1.Name());

target2 = RDK.Item('Target b3');
fprintf('Target 2 selected:\t%s\n', target2.Name());


% return
%% How to generate a robot program

% Clean up previous items automatically generated by this script
% the keyword "macro" is used if we want to delete any items when the
% script is executed again.
tic()
while 1
    item = RDK.Item('macro');
    if item.Valid() == 0
        % Iterate until there are no items with the "macro" name
        break
    end
    % if Valid() returns 1 it means that an item was found
    % if so, delete the item in the RoboDK station
    item.Delete();
end

% Set the home joints
jhome = [ 0, 0, 0, 0, 30, 0];

% Set the robot at the home position
robot.setJoints(jhome);

% Turn off rendering (faster)
RDK.Render(0);

% Get the tool pose
Htcp = tool.Htool();

% Create a reference frame with respect to the robot base reference
ref = RDK.AddFrame('Frame macro', frameref);
% Set the reference frame at coordinates XYZ, rotation of 90deg about Y plus rotation of 180 deg about Z
Hframe = transl(750,250,500)*roty(pi/2)*rotz(pi);
ref.setPose(Hframe);

% Set the robot's reference frame as the reference we just cretaed
robot.setFrame(ref);
% Set the tool frame
robot.setTool(tool);

% Get the position of the TCP wrt the robot base
Hhome = inv(Hframe)*robot.SolveFK(jhome)*Htcp;

% Create a new program "prog"
prog = RDK.AddProgram('Prog macro');

% Create a joint target home
target = RDK.AddTarget('Home', ref, robot);
target.setAsJointTarget();
target.setJoints(jhome)
% Add joint movement into the program
prog.MoveJ(target);

% Generate a sequence of targets and move along the targets (linear move)
angleY = 0;
for dy=600:-100:100
    targetname = sprintf('Target TY=%i RY=%i',dy,angleY);
    target = RDK.AddTarget(targetname,ref,robot);
    % Move along Z direction of the reference frame
    pose = transl(0,dy,0);
    % Keep the same orientation as home orientation
    pose(1:3,1:3) = Hhome(1:3,1:3);
    pose = pose*roty(angleY*pi/180);
    target.setPose(pose);
    prog.MoveL(target);
    angleY = angleY + 20;
end

% Set automatic render on every call
RDK.Render(1);

% Run the program we just created
prog.RunProgram();

% Wait for the movement to finish
while robot.Busy()
    pause(1);
    fprintf('Waiting for the robot to finish...\n');
end

% Run the program once again
fprintf('Running the program again...\n');
prog.RunProgram();


%% How to change the parent that an item is attached to

% Change the support of a target
% The final result of the operations made to target1 and target2 is the same
Htarget = target1.Pose();
target1.setParentStatic(frameref);
target1.setPose(Htarget);

target2.setParent(frameref);

% We can list the items that depend on an item
childs = frametable.Childs();
for i=1:numel(childs)
    name = childs{i}.Name();
    newname = [name,' modified'];
    visible = childs{i}.Visible();
    childs{i}.setName(newname);
    fprintf('%s %i\n',newname, visible);
end

%% How to Attach/Detach an object to the robot tool

% Attach the closest object to the tool
attached = tool.AttachClosest();
% If we know what object we want to attach, we can use this function
% instead: object.setParentStatic(tool);
if attached.Valid()
    attachedname = attached.Name();
    fprintf('Attached: %s\n', attachedname);
else
    % The tolerance can be changed in:
    % Tools->Options->General tab->Maximum distance to attach an object to
    % a robot tool (default is 1000 mm)
    fprintf('No object is close enough\n');
end
pause(2);
tool.DetachAll();
fprintf('Detached all objects\n');

%% How to scale an object and how to detect collisions

% Replace objects (we call the program previously set in example 1)
RDK.Item('Replace objects').RunProgram();

% Verify if a joint movement from j1 to j2 is free of colllision
j1 = [-100, -50, -50, -50, -50, -50];
j2 = [100, 50, 50, 50, 50, 50];
collision = robot.MoveJ_Test(j1, j2, 1);
disp(collision)
% Activate the trace to see what path the robot tries to make
% To activate the trace: Tools->Trace->Active (ALT+T)

% Detect collisions: returns the number of pairs of objects in a collision state
pairs = RDK.Collisions();
fprintf('Pairs collided: %i\n', pairs);

% Scale the geometry of an object, scale can be one number or a scale per axis
object.Scale([10, 10, 0.5]);

% Detect the intersection between a line and any object
p1 = [1000; 0; 8000];
p2 = [1000; 0;    0];
[collision, itempicked, xyz] = RDK.Collision_Line(p1, p2);
if itempicked.Valid()
    fprintf('Line from p1 to p2 collides with %s\n', itempicked.Name());
    % Create a point in the intersection to display collision
    ball.Copy();
    newball = RDK.Paste();
    % Set this ball at the collision point
    newball.setPose(transl(xyz(1),xyz(2),xyz(3)));
    newball.Scale(0.5); % Make this ball 50% of the original size
    newball.Recolor([1 0 0]); % Make it a red ball
end


%% How to move the robot programmaticall without creating a program

% Replace objects (we call the program previously set in example 1)
RDK.Item('Replace objects').RunProgram();

% RDK.setRunMode(1); % this performs a quick validation without showing the dynamic movement
% (1 = RUNMODE_QUICKVALIDATE)

fprintf('Moving by target item...\n');
robot.setFrame(frametable);
RDK.setSimulationSpeed(10);
for i=1:2    
    robot.setSpeed(10000,1000);  
    robot.MoveJ(target1);  
    robot.setSpeed(100,200);
    robot.MoveL(target2);
    
end

fprintf('Moving by joints...\n');
J1 = [0,0,0,0,50,0];
J2 = [40,30,-30,0,50,0];
for i=1:2
    robot.MoveJ(J1);
    robot.MoveL(J2);
end

fprintf('Moving by pose...\n');
% Follow these steps to retreive a pose:
% 1-Double click a robot
% 2-Copy the pose of the Tool frame with respect to the User Frame (as a Matrix)
% 3-Paste it here
H1 = [    -0.492404,    -0.642788,    -0.586824,  -101.791308 ;
     -0.413176,     0.766044,    -0.492404,  1265.638417 ;
      0.766044,     0.000000,    -0.642788,   117.851733 ;
      0.000000,     0.000000,     0.000000,     1.000000 ];

H2 = [    -0.759717,    -0.280123,    -0.586823,  -323.957442 ;
      0.060192,     0.868282,    -0.492405,   358.739694 ;
      0.647462,    -0.409410,    -0.642787,   239.313006 ;
      0.000000,     0.000000,     0.000000,     1.000000 ];
  
for i=1:2
    robot.MoveJ(H1);
    robot.MoveL(H2);
end

%% Calculate forward and inverse kinematics of a robot

% Get the current robot joints
fprintf('Current robot joints:\n');
joints = robot.Joints();
disp(joints);

% Get the current position of the TCP with respect to the reference frame
fprintf('Calculated pose for current joints:\n');
H_tcp_wrt_frame = robot.SolveFK(joints);
disp(H_tcp_wrt_frame);

% Calculate the joints to reach this position (should be the same as joints)
fprintf('Calculated robot joints from pose:\n');
joints2 = robot.SolveIK(H_tcp_wrt_frame);
disp(joints2);

% Calculate all solutions
fprintf('All solutions available for the selected position:\n');
joints3_all = robot.SolveIK_All(H_tcp_wrt_frame);
disp(joints3_all);

% Show the sequence in the slider bar in RoboDK
RDK.ShowSequence(joints3_all);

pause(1);
% Make joints 4 the solution to reach the target off by 100 mm in Z
joints4 = robot.SolveIK(H_tcp_wrt_frame*transl(0,0,-100));
% Set the robot at the new position calculated
robot.setJoints(joints4);

%% Example to add targets to a program and use circular motion
RDK = Robolink();
robot = RDK.Item('',RDK.ITEM_TYPE_ROBOT);

% Get the current robot pose:
pose0 = robot.Pose();

% Add a new program:
prog = RDK.AddProgram('TestProgram');

% Create a linear move to the current robot position (MoveC is defined by 3
% points)
target0 = RDK.AddTarget('First Point');
target0.setAsCartesianTarget(); % default behavior
target0.setPose(pose0);
prog.MoveL(target0);

% Calculate the circular move:
pose1 = pose0*transl(50,0,0);
pose2 = pose0*transl(50,50,0);

% Add the first target for the circular move
target1 = RDK.AddTarget('Second Point');
target1.setAsCartesianTarget();
target1.setPose(pose1);

% Add the second target for the circular move
target2 = RDK.AddTarget('Third Point');
target2.setAsCartesianTarget();
target2.setPose(pose2);

% Add the circular move instruction:
prog.MoveC(target1, target2)

