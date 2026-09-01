# Demo Patient Leads — Metromind Hospital (Neuropsychiatric)

Sample lead records for demoing the WhatsApp CRM patient pipeline, built for a neuropsychiatric hospital: Psychiatry, Neurology, Child & Adolescent Psychiatry, and De-addiction. Each row is one inbound enquiry, structured to match the lead-capture flow fields (Lead ID, Patient Name, Mobile, Age, Gender, Location, Service/Department, Reason for Enquiry, Preferred Contact Method, Preferred Appointment Date/Time, Source, Additional Message).

To load these into the live pipeline, see [demo-seed-neuropsychiatric.sql](demo-seed-neuropsychiatric.sql) — a script you run once in the Supabase SQL Editor. It replaces any existing pipeline data with a fresh "Patient Journey" pipeline seeded with these 10 cases.

| Lead ID | Date & Time | Patient Name | Mobile Number | Age | Gender | Location | Service / Department | Reason for Enquiry | Preferred Contact Method | Preferred Appointment Date | Preferred Appointment Time | How Did You Hear About Us? | Additional Message |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| MM0301 | 01/09/2026, 10:15 AM | Anjali Menon | 9847123456 | 34 | Female | Kakkanad, Ernakulam | Psychiatry | Anxiety and sleep disturbance for 2 months | WhatsApp | 05/09/2026 | Morning | Instagram | Would like a female doctor if possible |
| MM0302 | 01/09/2026, 10:50 AM | Ravi Chandran | 9895567234 | 45 | Male | Kaloor, Ernakulam | Neurology | Recurrent seizure episodes over the last month | Call | 03/09/2026 | Evening | Google Search | Bringing prior EEG report |
| MM0303 | 01/09/2026, 11:30 AM | Fathima Rasheed | 9744890123 | 29 | Female | Aluva | Psychiatry | Postpartum depression, 6 weeks after delivery | WhatsApp | 07/09/2026 | Afternoon | Referral | Referred by her gynecologist |
| MM0304 | 01/09/2026, 12:10 PM | Arjun Nair | 9633445678 | 8 | Male | Edappally | Child & Adolescent Psychiatry | Inattention and hyperactivity at school, ADHD evaluation | Call | 06/09/2026 | Morning | Referral | Referred by school counselor |
| MM0305 | 01/09/2026, 1:00 PM | Manoj Pillai | 9744223344 | 62 | Male | Thrippunithura | Neurology (Memory Clinic) | Progressive memory loss over 6 months, suspected early dementia | WhatsApp | 10/09/2026 | Morning | Google Search | Family requests a joint consult with them present |
| MM0306 | 01/09/2026, 1:45 PM | Priya Varma | 9946778812 | 24 | Female | Vyttila | Psychiatry | Recurrent panic attacks with palpitations, triggered at work | WhatsApp | 04/09/2026 | Evening | Instagram | Prefers evening slots after 6 PM |
| MM0307 | 01/09/2026, 2:30 PM | Sarath Kumar | 9895667788 | 38 | Male | Palarivattom | De-addiction Psychiatry | Alcohol dependence, family-initiated enquiry | Call | 08/09/2026 | Afternoon | Walk-in Enquiry | Family asking about inpatient de-addiction program |
| MM0308 | 01/09/2026, 3:15 PM | Deepa Krishnan | 9847001122 | 52 | Female | Kadavanthra | Neurology | Chronic migraine, 15+ headache days per month | WhatsApp | 31/08/2026 | Morning | Referral | Already admitted for 2-day observation |
| MM0309 | 01/09/2026, 4:00 PM | Vishnu Prasad | 9633009988 | 19 | Male | Thevara | Psychiatry | Intrusive thoughts and repetitive checking behaviour for over a year | WhatsApp | 09/09/2026 | Afternoon | Google Search | Self-referred after reading about OCD online |
| MM0310 | 01/09/2026, 4:40 PM | Sarah Thomas | 9846556677 | 70 | Female | Kochi | Neurology | Existing Parkinson's disease patient, medication review | Call | 10/09/2026 | Morning | Referral | Long-term patient, needs physiotherapy plan too |

## Pipeline mapping

Each row becomes one **Patient Case** card, seeded into the **New Inquiry** stage:

- **Case Title** → `{Service/Department} – {Patient Name}`
- **Patient** → linked contact (created from Mobile Number if new)
- **Consultation Fee (₹)** → filled once the department's standard fee is confirmed at booking
- **Appointment Date** → Preferred Appointment Date
- **Doctor / Staff** → assigned once appointment is confirmed
- **Clinical Notes** → Reason for Enquiry + Additional Message

As each lead progresses, the same card moves stage-to-stage (New Inquiry → Appointment Booked → Consultation Done → Treatment Planned → Admitted) rather than being duplicated.
