# Demo Patient Leads — Metromind Hospital

Sample lead records for demoing the WhatsApp CRM patient pipeline. Each row is one inbound enquiry, structured to match the lead-capture flow fields (Lead ID, Patient Name, Mobile, Age, Gender, Location, Service/Department, Reason for Enquiry, Preferred Contact Method, Preferred Appointment Date/Time, Source, Additional Message).

| Lead ID | Date & Time | Patient Name | Mobile Number | Age | Gender | Location | Service / Department | Reason for Enquiry | Preferred Contact Method | Preferred Appointment Date | Preferred Appointment Time | How Did You Hear About Us? | Additional Message |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| MM0247 | 01/09/2026, 11:30 AM | Anjali Menon | 9847123456 | 34 | Female | Kakkanad, Ernakulam | Psychiatry | Consultation for anxiety and sleep issues | WhatsApp | 05/09/2026 | Morning | Instagram | Would like a female doctor if possible |
| MM0248 | 01/09/2026, 12:05 PM | Vishnu Prasad | 9895567234 | 58 | Male | Kaloor, Ernakulam | Orthopedics | Persistent knee pain, difficulty climbing stairs | Call | 04/09/2026 | Evening | Google Search | Has an old MRI report to share |
| MM0249 | 01/09/2026, 1:40 PM | Fathima Rasheed | 9744890123 | 41 | Female | Aluva | Cardiology | Chest discomfort during exercise, family history of heart disease | WhatsApp | 06/09/2026 | Morning | Referral | Referred by Dr. Suresh, Aluva Clinic |
| MM0250 | 01/09/2026, 2:15 PM | Arjun Nair | 9633445678 | 6 | Male | Edappally | Pediatrics | Recurring fever and cough for 3 days | Call | 02/09/2026 | Morning | Facebook | First-time patient, needs new registration |
| MM0251 | 01/09/2026, 3:00 PM | Priya Varma | 9946778812 | 27 | Female | Vyttila | Dermatology | Acne and skin allergy consultation | WhatsApp | 07/09/2026 | Afternoon | Instagram | Prefers evening slots after 5 PM |
| MM0252 | 01/09/2026, 4:20 PM | Sarah Thomas | 9847001122 | 30 | Female | Palarivattom | Gynecology | Routine prenatal checkup, 20 weeks pregnant | WhatsApp | 03/09/2026 | Morning | Referral | Existing patient, second visit |
| MM0253 | 01/09/2026, 5:10 PM | Manoj Pillai | 9744223344 | 45 | Male | Thrippunithura | ENT | Chronic sinus congestion and hearing discomfort | Call | 08/09/2026 | Afternoon | Google Search | Works night shifts, only available after 6 PM |
| MM0254 | 01/09/2026, 6:00 PM | Deepa Krishnan | 9895667788 | 62 | Female | Kadavanthra | General Medicine | Diabetes follow-up and routine blood work | WhatsApp | 02/09/2026 | Morning | Walk-in Enquiry | Needs help scheduling lab tests same day |

## Pipeline mapping

Each row becomes one **Patient Case** card, seeded into the **New Inquiry** stage:

- **Case Title** → `{Service/Department} – {Patient Name}`
- **Patient** → linked contact (created from Mobile Number if new)
- **Consultation Fee (₹)** → filled once the department's standard fee is confirmed at booking
- **Appointment Date** → Preferred Appointment Date
- **Doctor / Staff** → assigned once appointment is confirmed
- **Clinical Notes** → Reason for Enquiry + Additional Message

As each lead progresses, the same card moves stage-to-stage (New Inquiry → Appointment Booked → Consultation Done → Treatment Planned → Admitted) rather than being duplicated.
