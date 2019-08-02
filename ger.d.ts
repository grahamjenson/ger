/* eslint-disable @typescript-eslint/camelcase */
/* eslint-disable camelcase */
declare module 'ger' {
  export interface EventDates {
    created_at?: Date | string
    expires_at?: Date | string
  }

  export interface Event extends EventDates {
    thing: string
    action: string
    person: string
    namespace: string
  }

  export interface CalculateSimilaritiesConfiguration {
    similarity_search_size: number
    event_decay_rate: number
    current_datetime: Date
  }

  export class EventStoreManager {
    constructor(options: any)

    initialize(namespace: string): Promise<void>

    destroy(namespace: string): Promise<void>

    exists(namespace: string): Promise<boolean>

    list_namespaces(): Promise<any[]>

    add_events(event: Event[]): Promise<any[]>

    count_events(namespace: string): Promise<number>

    estimate_event_count(namespace: string): Promise<number>

    add_event(
      namespace: string,
      person: string,
      action: string,
      thing: string,
      dates: EventDates
    ): Promise<any>

    find_events()

    delete_events()

    thing_neighbourhood()

    calculate_similarities_from_thing()

    person_neighbourhood()

    calculate_similarities_from_person()

    filter_things_by_previous_actions()

    recent_recommendations_by_people()
  }

  export type Actions = Record<string, number>

  export interface Configuration {
    actions: Actions
    minimum_history_required: number
    similarity_search_size: number
    neighbourhood_size: number
    reccomendations_per_neightbour: number
    filter_previous_actions: string[]
    event_decay_rate: number
    time_until_expiry: number
  }

  export interface Recommendation {
    thing: string
    weight: number
    last_actioned_at: Date
    last_expires_at: Date
    people: string[]
  }

  export type RecommendationNeighbourhood = Record<string, number>

  export interface Recommendations {
    reccomendations: Recommendation[]
    neighbourhood: RecommendationNeighbourhood
    confidence: number
  }

  export class GER {
    constructor(esm: EventStoreManager)

    initialize_namespace(namespace: string): Promise<void>

    destroy_namespace(namespace: string): Promise<void>

    namespace_exists(namespace: string): Promise<boolean>

    list_namespaces(): Promise<string[]>

    add_events(event: Event[]): Promise<Event[]>

    events(events: Event[]): Promise<Event[]>

    event(
      namespace: string,
      person: string,
      action: string,
      thing: string,
      dates?: EventDates
    ): Promise<{ person: string; action: string; thing: string }>

    find_events(namespace: string, options: any): Promise<Event[]>

    delete_events(
      namespace: string,
      person: string,
      action: string,
      thing: string
    ): Promise<{ deleted: number }>

    calculate_similarities_from_thing(
      namespace: string,
      thing: string,
      things: any[],
      actions: string[],
      configuration: CalculateSimilaritiesConfiguration
    ): Promise<any>

    calculate_similarities_from_person(
      namespace: string,
      thing: string,
      things: any[],
      actions: string[],
      configuration: CalculateSimilaritiesConfiguration
    ): Promise<any>

    recommendations_for_person(
      namespace: string,
      person: string,
      configuration?: Partial<Configuration>
    ): Promise<Recommendations>

    recommendations_for_thing(
      namespace: string,
      person: string,
      configuration?: Partial<Configuration>
    ): Promise<Recommendations>

    count_events(namespace: string): Promise<number>

    estimate_event_count(namespace: string): Promise<number>
  }

  export class MemESM extends EventStoreManager {}

  export interface PsqlESMOptions {
    knex: any
  }

  export class PsqlESM extends EventStoreManager {
    constructor(options: PsqlESMOptions)
  }

  export const NamespaceDoestNotExist: Error
}
