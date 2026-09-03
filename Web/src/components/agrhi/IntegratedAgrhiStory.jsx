import React from "react";
import { ArrowRight, Check, ExternalLink, Leaf, ShieldCheck } from "lucide-react";
import { appComponents, events, officialLinks, partners, pillars, projectFacts, technologies } from "../../data/projectData";
import { pageContent } from "../../data/pageContent";
import "./integratedAgrhiStory.css";
import AnimatedContent from "../reactbits/AnimatedContent";
import SpotlightCard from "../reactbits/SpotlightCard";

const flow = ["Research", "Education", "Technology", "Demonstration", "Farmer knowledge", "Field feedback"];

function Heading({ label, title, intro }) {
  return <AnimatedContent className="ias-heading"><span>{label}</span><h2>{title}</h2>{intro && <p>{intro}</p>}</AnimatedContent>;
}

function Narrative({ section, reverse = false }) {
  return <AnimatedContent className={reverse ? "ias-narrative reverse" : "ias-narrative"}>
    <div><span className="ias-label">{section.label}</span><h3>{section.title}</h3>{section.paragraphs.map(p => <p key={p}>{p}</p>)}</div>
    <div className="ias-points">{section.cards.map((item, i) => <article key={item}><b>{String(i + 1).padStart(2, "0")}</b><span>{item}</span><Check size={16}/></article>)}</div>
  </AnimatedContent>;
}

function Panels({ items }) {
  return <div className="ias-panels">{items.map(([title, text], index) => <AnimatedContent key={title} delay={Math.min(index, 2) * .07}><SpotlightCard><small>{String(index + 1).padStart(2,"0")}</small><h3>{title}</h3><p>{text}</p></SpotlightCard></AnimatedContent>)}</div>;
}

export default function IntegratedAgrhiStory() {
  return <div className="agrhi-story" id="agrhi-project">
    <section className="ias-intro"><div className="ias-shell ias-intro-grid"><div>
      <div className="ias-kicker"><Leaf size={15}/> AGRHI Erasmus+ project</div>
      <h2>From agricultural knowledge to practical digital tools</h2>
      <p>{pageContent.project.intro}</p>
      <div className="ias-actions"><a href="#smart-agriculture">Explore smart agriculture <ArrowRight size={16}/></a><a className="light" href={officialLinks.project} target="_blank" rel="noreferrer">Official AGRHI project <ExternalLink size={15}/></a></div>
    </div><div className="ias-facts">{projectFacts.map(([name,value]) => <div key={name}><span>{name}</span><strong>{value}</strong></div>)}</div></div></section>

    <div className="ias-shell">
      <Narrative section={pageContent.project.sections[0]}/>
      <Narrative section={pageContent.project.sections[1]} reverse/>
    </div>

    <section className="ias-flow"><div className="ias-shell"><Heading label="Classrooms to farms" title="Knowledge improves when it moves in both directions"/><ol>{flow.map((step,index) => <li key={step}><b>{index + 1}</b><span>{step}</span>{index < flow.length - 1 && <ArrowRight/>}</li>)}</ol></div></section>

    <section className="ias-block"><div className="ias-shell"><Heading label="Project foundations" title="Six connected pillars for agricultural capacity building"/><Panels items={pillars.map(([,title,text]) => [title,text])}/></div></section>

    <section className="ias-chapter ias-chapter--smart" id="smart-agriculture"><div className="ias-shell"><Heading label={pageContent.smart.eyebrow} title={pageContent.smart.title} intro={pageContent.smart.intro}/><Narrative section={pageContent.smart.sections[0]}/><Narrative section={pageContent.smart.sections[1]} reverse/><Heading label="Verified platform architecture" title="The AGRHI digital ecosystem"/><Panels items={appComponents}/><Narrative section={pageContent.smart.sections[2]}/><aside className="ias-warning"><ShieldCheck/><div><h3>Responsible decision support</h3><p>AGRHI’s AI output is guidance, not a substitute for professional agricultural advice. Image quality, crop variety and conditions outside training data can affect a result, so predictions should be verified with a local expert before action.</p></div></aside></div></section>

    <section className="ias-chapter" id="innovation"><div className="ias-shell"><Heading label={pageContent.innovation.eyebrow} title={pageContent.innovation.title} intro={pageContent.innovation.intro}/><Narrative section={pageContent.innovation.sections[0]}/><Heading label="Technology in action" title="Tools become meaningful through practical learning"/><Panels items={technologies}/><Narrative section={pageContent.innovation.sections[1]} reverse/><Narrative section={pageContent.innovation.sections[2]}/></div></section>

    <section className="ias-chapter ias-chapter--erasmus" id="erasmus"><div className="ias-shell"><Heading label={pageContent.erasmus.eyebrow} title={pageContent.erasmus.title} intro={pageContent.erasmus.intro}/><Narrative section={pageContent.erasmus.sections[0]}/><Narrative section={pageContent.erasmus.sections[1]} reverse/><div className="ias-partners"><Heading label="AGRHI consortium" title="Eleven partners across six countries"/><div>{partners.map(group => <article key={group.country}><h3>{group.country}</h3><ul>{group.institutions.map(name => <li key={name}>{name}</li>)}</ul></article>)}</div></div><Narrative section={pageContent.erasmus.sections[2]}/></div></section>

    <section className="ias-events"><div className="ias-shell"><Heading label="Knowledge exchange" title="A connected programme of training, workshops and conferences"/><div className="ias-timeline">{events.map(event => <article key={event.title}><time>{event.year}</time><div><small>{event.type} · {event.place}</small><h3>{event.title}</h3><p>{event.text}</p></div></article>)}</div></div></section>

    <section className="ias-close"><div className="ias-shell"><span>From knowledge to fields</span><h2>Agricultural progress is built through people, skills and useful technology.</h2><p>AGRHI provides a foundation for continuing education, research collaboration, farmer-oriented innovation and responsible digital agriculture.</p><div className="ias-actions"><a href="https://play.google.com/apps/testing/app.agrhi.com" target="_blank" rel="noreferrer">Get AGRHI App <ArrowRight size={16}/></a><a className="light" href="#contact">Contact support</a></div></div></section>
  </div>;
}
