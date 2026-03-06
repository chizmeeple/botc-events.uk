---
layout: default
title: "Upcoming Events"
description: "Browse upcoming Blood on the Clocktower events across the UK. Find game nights, meetups and sessions near you."
permalink: /events/
---

<div class="content-page club-detail">
  <h1>Upcoming events</h1>

  {% assign all_events = site.data.rendered_events.all_upcoming %}
  {% if all_events and all_events.size > 0 %}
  {% assign by_date = all_events | group_by_exp: "item", "item.start_time | date: '%Y-%m-%d'" %}
  <div class="club-upcoming-events">
    {% for group in by_date %}
    <h2>{{ group.items[0].start_time | date: "%A, %d %B %Y" }}</h2>
    <ul class="upcoming-events-list">
      {% for occ in group.items %}
      {% include event-card.html occ=occ club_slug=occ.slug club_name=occ.club_name %}
      {% endfor %}
    </ul>
    {% endfor %}
  </div>
  {% else %}
  <p class="upcoming-events-empty">No upcoming events scheduled. Check back soon or <a href="{{ '/add-event' | relative_url }}">add an event</a>.</p>
  {% endif %}
</div>
