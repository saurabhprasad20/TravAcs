\# Travacs – Product Vision, Requirements, Constraints, and High-Level Solution



\## Overview



Travacs is a mobile platform designed to connect visually impaired individuals who require travel or mobility assistance with trusted volunteers who are willing to provide that assistance for a predefined duration and compensation.



The primary objective of the platform is to enable visually impaired users to travel independently and confidently by providing a reliable mechanism to find and engage nearby assistance when needed.



Examples of assistance requests may include:



\* Walking from home to a nearby market.

\* Traveling to a metro station or bus stop.

\* Assistance during shopping trips.

\* Attending appointments, events, or social gatherings.

\* General outdoor mobility support.



The platform will initially focus on simplicity, accessibility, reliability, and ease of use rather than large-scale feature richness.



\---



\# User Types



\## 1. Visually Impaired User (Requester)



A visually impaired user can:



\* Register and create a profile.

\* Request travel assistance.

\* Specify travel requirements.

\* Specify date and time.

\* Specify pickup and destination details.

\* View request status.

\* Start and end trips.

\* Rate volunteers after trip completion.

\* Make payments directly to volunteers outside the application.



\---



\## 2. Volunteer (Travacser)



A volunteer can:



\* Register and create a profile.

\* Complete verification requirements. (uploads their aadhar which admin will approve and they become a travacs). 

\* Receive assistance requests.

\* Accept available requests.

\* Assist the requester during the trip.

\* Mark trip start and completion.

\* Receive payment directly from the requester.

\* Receive ratings and feedback.



\---



\# Core Business Flow



\## Step 1 – User Registration



Both user categories register through the application.



Required information may include:



\### Visually Impaired User



\* Name, gender, date of birth

\* Phone number

\* Location information



\### Volunteer (TravAcser)



\* Name

\* Phone number

\* Profile details (gender, date of birth, Aadhar). 

\*Address



\---



\## Step 2 – Assistance Request Creation



The visually impaired user creates a request containing:



\* Date

\* Start time

\* Expected duration

\* Pickup location

\* Destination

\* Assistance requirements

\* Additional instructions



Example:



"I need assistance from my home to the nearest metro station tomorrow at 9:00 AM for approximately one hour."



\---



\## Step 3 – Request Notification



The system broadcasts the request to eligible volunteers.



The notification contains:



\* Pickup location

\* Destination

\* Requested timing

\* Estimated duration



\---



\## Step 4 – Volunteer Acceptance



Volunteers can view and accept requests.



Assignment follows a First-Come-First-Serve (FCFS) model.



Important rule:



\* Multiple volunteers may attempt acceptance simultaneously.

\* The backend system must ensure that only the first successful volunteer receives the assignment.

\* All subsequent acceptance attempts must be rejected.



This logic must be enforced server-side to guarantee consistency and reliability.



\---



\## Step 5 – Assignment Confirmation



After successful assignment:



Requester receives:



\* Volunteer details

\* Contact information



Volunteer receives:



\* Request details

\* User information

\* Contact information



\---



\## Step 6 – Trip Start



When both parties meet:



user shares an OTP with TravAcser

TravAcser inputs and verifies the otp initiates the trip through the application.



Trip status changes to:



"Started"



The start time is recorded by the system.



\---



\## Step 7 – Trip Completion



After the assistance is completed:



Either party marks the trip as completed.



The system records:



\* End time

\* Actual duration

\* Trip completion status



The application calculates the payable amount based on the predefined hourly rate.

for now, 1 hour = 135 INR. 



\---



\## Step 8 – Payment



For the initial release, payment processing will not be integrated into the application.



Instead:



\* The application calculates the amount due.

\* Payment occurs directly between the requester and volunteer using external methods such as UPI.

\* The volunteer confirms receipt of payment.



This approach avoids payment gateway integration complexity and platform commission concerns during the early stages.



\---



\## Step 9 – Ratings and Feedback



After completion:



Requester can rate the volunteer.



Volunteer can rate the requester.



Ratings help build trust and improve platform quality.



\---



\# Accessibility Requirements



Accessibility is a primary requirement and not an optional feature.



The application must be fully usable by visually impaired users.



Requirements include:



\* Screen reader compatibility.

\* VoiceOver support on iOS.

\* TalkBack support on Android.

\* Proper semantic labels.



\---



\# Non-Functional Requirements



\## Reliability



The platform must provide consistent operation with minimal failures.



Requirements include:



\* Reliable request creation.

\* Reliable assignment processing.

\* Reliable trip tracking.

\* Reliable notifications.



\---



\## Availability



The platform should remain available at all times except for planned maintenance.



Target:



\* High availability suitable for a consumer-facing service.



\---



\## Performance



Expected initial user base:



\* Less than 1,000 users.



The system should be optimized for responsiveness rather than massive scale.



Future scalability should be possible without requiring complete redesign.



\---



\## Security



The platform should ensure:



\* Secure authentication.

\* Protection of personal information.

\* Secure communication between application and backend.



\---



\# Constraints



\## Development Bandwidth



The team has limited engineering capacity.



Maintaining separate Android and iOS codebases would significantly increase development and maintenance effort.



A single codebase approach is strongly preferred.



\---



\## Cost Constraints



The project is in an early-stage validation phase.



Infrastructure costs should remain minimal until meaningful adoption is achieved.



The architecture should prioritize:



\* Low operational cost.

\* Simplicity.

\* Fast development.



\---



\## Scale Constraints



Initial expected scale:



\* Fewer than 1,000 users.



The architecture should support future growth but should not be over-engineered for large-scale traffic on day one.



\---



\# Recommended Technical Approach



\## Mobile Application



Flutter



Reasons:



\* Single codebase.

\* Android support.

\* iOS support.

\* Strong accessibility support.

\* Reduced development effort.



\---



\## Backend Platform



Supabase



Provides:



\* Authentication.

\* PostgreSQL database.

\* Storage.

\* Real-time capabilities.

\* Backend functions.



Benefits:



\* Low cost.

\* Fast development.

\* Suitable for initial scale.



\---



\## Notifications



Firebase Cloud Messaging (FCM)



Used for:



\* New request notifications.

\* Assignment notifications.

\* Trip updates.



\---



\## Initial Payment Model



External payment methods such as UPI.



No in-app payment integration during the initial phase.



This reduces:



\* Development complexity.

\* Operational overhead.

\* Platform review concerns.



\---



\# Success Criteria for Initial Release



The first version of Travacs should successfully allow:



1\. Registration of visually impaired users.

2\. Registration of volunteers.

3\. Creation of assistance requests.

4\. Volunteer acceptance of requests.

5\. Trip start and completion tracking.

6\. Direct payment coordination.

7\. Ratings and feedback.

8\. Accessible user experience for visually impaired users.



The primary goal of the first release is to validate demand, user adoption, volunteer participation, and operational workflows before investing in advanced features or large-scale infrastructure.



