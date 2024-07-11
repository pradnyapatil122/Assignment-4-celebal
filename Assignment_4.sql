-- Create SubjectDetails table
CREATE TABLE SubjectDetails (
    SubjectID nvarchar(50) PRIMARY KEY,
    SubjectName nvarchar(60) NOT NULL,
    MaxSeats int NOT NULL,
    RemainingSeats int NOT NULL
);

-- Insert data into SubjectDetails table
INSERT INTO SubjectDetails VALUES 
('PO1491', 'Basics of Political Science', 60, 2),
('PO1492', 'Basics of Accounting', 120, 119),
('PO1493', 'Basics of Financial Markets', 90, 90),
('PO1494', 'Eco philosophy', 60, 50),
('PO1495', 'Automotive Trends', 60, 60);

-- Create StudentDetails table
CREATE TABLE StudentDetails (
    StudentID int PRIMARY KEY,
    StudentName nvarchar(50) NOT NULL,
    GPA float NOT NULL,
    Branch nvarchar(10) NOT NULL,
    Section nvarchar(2) NOT NULL
);

-- Insert data into StudentDetails table
INSERT INTO StudentDetails VALUES
(159103036, 'Mohit Agarwal', 8.9, 'CCE', 'A'),
(159103037, 'Rohit Agarwal', 5.2, 'CCE', 'A'),
(159103038, 'Shohit Garg', 7.1, 'CCE', 'B'),
(159103039, 'Mrinal Malhotra', 7.9, 'CCE', 'A'),
(159103040, 'Mehreet Singh', 5.6, 'CCE', 'A'),
(159103041, 'Arjun Tehlan', 9.2, 'CCE', 'B');

-- Create StudentPreference table
CREATE TABLE StudentPreference (
    StudentID int NOT NULL,
    SubjectID nvarchar(50) NOT NULL,
    Preferences int NOT NULL,
    PRIMARY KEY (StudentID, Preferences),
    FOREIGN KEY (StudentID) REFERENCES StudentDetails(StudentID),
    FOREIGN KEY (SubjectID) REFERENCES SubjectDetails(SubjectID)
);

-- Insert data into StudentPreference table
INSERT INTO StudentPreference VALUES 
(159103036, 'PO1491', 1),
(159103036, 'PO1492', 2),
(159103036, 'PO1493', 3),
(159103036, 'PO1494', 4),
(159103036, 'PO1495', 5);


-- Create the Allotments table
CREATE TABLE Allotments (
    SubjectID nvarchar(50) NOT NULL,
    StudentID int NOT NULL,
    PRIMARY KEY (SubjectID, StudentID),
    FOREIGN KEY (SubjectID) REFERENCES SubjectDetails(SubjectID),
    FOREIGN KEY (StudentID) REFERENCES StudentDetails(StudentID)
);

-- Create the UnallottedStudents table
CREATE TABLE UnallottedStudents (
    StudentID int NOT NULL PRIMARY KEY,
    FOREIGN KEY (StudentID) REFERENCES StudentDetails(StudentID)
);


CREATE PROCEDURE AllocateSubjects
AS
BEGIN
    SET NOCOUNT ON;

    -- Temporary table to track remaining seats for each subject
    CREATE TABLE #TempSubjectSeats (
        SubjectID nvarchar(50) PRIMARY KEY,
        RemainingSeats int
    );

    -- Populate temporary table with remaining seats
    INSERT INTO #TempSubjectSeats (SubjectID, RemainingSeats)
    SELECT SubjectID, RemainingSeats
    FROM SubjectDetails;

    -- Table to hold the allocation results
    CREATE TABLE #TempAllotments (
        StudentID int,
        SubjectID nvarchar(50),
        Preferences int,
        PRIMARY KEY (StudentID, Preferences)
    );

    -- Allocate subjects based on GPA and preferences
    INSERT INTO #TempAllotments (StudentID, SubjectID, Preferences)
    SELECT sp.StudentID, sp.SubjectID, sp.Preferences
    FROM StudentPreference sp
    JOIN StudentDetails sd ON sp.StudentID = sd.StudentID
    JOIN #TempSubjectSeats ts ON sp.SubjectID = ts.SubjectID
    WHERE ts.RemainingSeats > 0
    ORDER BY sd.GPA DESC, sp.Preferences ASC;

    -- Insert into Allotments and update remaining seats
    DECLARE @StudentID int, @SubjectID nvarchar(50);
    DECLARE @RemainingSeats int;

    DECLARE allocation_cursor CURSOR FOR
    SELECT StudentID, SubjectID
    FROM #TempAllotments
    ORDER BY StudentID, Preferences;

    OPEN allocation_cursor;
    FETCH NEXT FROM allocation_cursor INTO @StudentID, @SubjectID;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        -- Check remaining seats for the subject
        SELECT @RemainingSeats = RemainingSeats
        FROM #TempSubjectSeats
        WHERE SubjectID = @SubjectID;

        IF @RemainingSeats > 0
        BEGIN
            -- Allocate subject to student
            INSERT INTO Allotments (SubjectID, StudentID) VALUES (@SubjectID, @StudentID);

            -- Decrease the remaining seats
            UPDATE #TempSubjectSeats
            SET RemainingSeats = RemainingSeats - 1
            WHERE SubjectID = @SubjectID;
        END

        FETCH NEXT FROM allocation_cursor INTO @StudentID, @SubjectID;
    END

    CLOSE allocation_cursor;
    DEALLOCATE allocation_cursor;

    -- Find unallotted students
    INSERT INTO UnallottedStudents (StudentID)
    SELECT sd.StudentID
    FROM StudentDetails sd
    LEFT JOIN Allotments a ON sd.StudentID = a.StudentID
    WHERE a.StudentID IS NULL;

    DROP TABLE #TempSubjectSeats;
    DROP TABLE #TempAllotments;
    SET NOCOUNT OFF;
END;

Execute AllocateSubjects;
SELECT * FROM Allotments;
SELECT * FROM UnallottedStudents;
